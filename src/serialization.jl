#####
##### `recordings.msgpack.zst` file content (de)serialization
#####

struct Header
    onda_format_version::VersionNumber
    ordered_keys::Bool
end

MsgPack.msgpack_type(::Type{Header}) = MsgPack.StructType()

"""
    deserialize_recordings_msgpack_zst(bytes::Vector{UInt8})

Return the `(header::Header, recordings::Dict{UUID,Recording})` yielded from deserializing `bytes`,
which is assumed to be in zstd-compressed MsgPack format and comply with the Onda format's specification of
the contents of `recordings.msgpack.zst`.
"""
function deserialize_recordings_msgpack_zst(bytes::Vector{UInt8})
    io = IOBuffer(zstd_decompress(bytes))
    read(io, UInt8) == 0x92 || error("Onda recordings file has unexpected first byte; expected 0x92 for a 2-element MsgPack array")
    header = MsgPack.unpack(io, Header)
    if !is_supported_onda_format_version(header.onda_format_version)
        @warn("attempting to load `Dataset` recordings file with unsupported Onda version",
              minimum_supported=MINIMUM_ONDA_FORMAT_VERSION,
              maximum_supported=MAXIMUM_ONDA_FORMAT_VERSION,
              attempting=header.onda_format_version)
        @warn("if your dataset is version v0.2, consider upgrading it via `Onda.upgrade_onda_format_from_v0_2_to_v0_3!`")
    end
    strict = header.ordered_keys ? (Recording,) : ()
    recordings = MsgPack.unpack(io, Dict{UUID,Recording}; strict=strict)
    return header, recordings
end

"""
    serialize_recordings_msgpack_zst(header::Header, recordings::Dict{UUID,Recording})

Return the `Vector{UInt8}` that results from serializing `(header::Header, recordings::Dict{UUID,Recording})` to zstd-compressed MsgPack format.
"""
function serialize_recordings_msgpack_zst(header::Header, recordings::Dict{UUID,Recording})
    # we do this `resize!` maneuver instead of `MsgPack.pack([header, recordings])` (which
    # calls `take!`) so that we sidestep https://github.com/JuliaLang/julia/issues/27741
    io = IOBuffer()
    MsgPack.pack(io, [header, recordings])
    return zstd_compress(resize!(io.data, io.size))
end

#####
##### LPCM Serialization API basic types/functions/stubs
#####
#=
TODO: Document new Serialization API:

deserializing_lpcm_stream(format::AbstractLPCMFormat, io)::AbstractLPCMStream
serializing_lpcm_stream(format::AbstractLPCMFormat, io)::AbstractLPCMStream
finalize_lpcm_stream(stream::AbstractLPCMStream)::Bool

deserialize_lpcm(format::AbstractLPCMFormat, bytes, samples_offset=0, samples_count=typemax(Int))
deserialize_lpcm(stream::AbstractLPCMStream, samples_offset=0, samples_count=typemax(Int))

serialize_lpcm(format::AbstractLPCMFormat, samples::AbstractMatrix)
serialize_lpcm(stream::AbstractLPCMStream, samples::AbstractMatrix)

deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)
=#

"""
    AbstractLPCMFormat

A type whose subtypes support TODO

All subtypes of the form `F<:AbstractLPCMFormat` must support a constructor of
the form `F(::Signal)` and overload `Onda.format_constructor_for_file_extension`
with the appropriate file extension.

See also:

- [`format`](@ref)
- [`deserialize_lpcm`](@ref)
- [`deserialize_lpcm_callback`](@ref)
- [`serialize_lpcm`](@ref)
- [`deserializing_lpcm_stream`](@ref)
- [`serializing_lpcm_stream`](@ref)
- [`finalize_lpcm_stream`](@ref)
- [`LPCM`](@ref)
- [`LPCMZst`](@ref)
"""
abstract type AbstractLPCMFormat end

"""
TODO
"""
abstract type AbstractLPCMStream end

"""
    Onda.format_constructor_for_file_extension(::Val{:extension_symbol})

Return a constructor of the form `F(::Signal)::AbstractLPCMFormat`
corresponding to the provided extension.

This function should be overloaded for new `AbstractLPCMFormat` subtypes.
"""
function format_constructor_for_file_extension(::Val{unknown}) where {unknown}
    throw(ArgumentError("unknown file extension: $unknown"))
end

"""
    format(signal::Signal; kwargs...)

Return `F(signal; kwargs...)` where `F` is the `AbstractLPCMFormat` that
corresponds to `signal.file_extension` (as determined by the format author
via `format_constructor_for_file_extension`).

See also: [`deserialize_lpcm`](@ref), [`serialize_lpcm`](@ref)
"""
function format(signal::Signal; kwargs...)
    F = format_constructor_for_file_extension(Val(signal.file_extension))
    return F(signal; kwargs...)
end

"""
TODO
"""
function deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)
    callback = bytes -> deserialize_lpcm(format, bytes, samples_offset, samples_count)
    return callback, missing, missing
end

"""
    deserializing_lpcm_stream(format::AbstractLPCMFormat, io)::AbstractLPCMStream

TODO
"""
function deserializing_lpcm_stream end

"""
    serializing_lpcm_stream(format::AbstractLPCMFormat, io)::AbstractLPCMStream

TODO
"""
function serializing_lpcm_stream end

"""
    finalize_lpcm_stream(stream::AbstractLPCMStream)::Bool

TODO
"""
function finalize_lpcm_stream end

"""
    deserialize_lpcm(format::AbstractLPCMFormat, bytes, samples_offset=0, samples_count=typemax(Int))
    deserialize_lpcm(stream::AbstractLPCMStream, samples_offset=0, samples_count=typemax(Int))

TODO
"""
function deserialize_lpcm end

"""
    serialize_lpcm(format::AbstractLPCMFormat, samples::AbstractMatrix)
    serialize_lpcm(stream::AbstractLPCMStream, samples::AbstractMatrix)

TODO
"""
function serialize_lpcm end

#####
##### `LPCM`
#####

const LPCM_SAMPLE_TYPE_UNION = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64}

"""
    LPCM{S}(channel_count)
    LPCM(signal::Signal)

Return a `LPCM<:AbstractLPCMFormat` instance corresponding to Onda's default
interleaved LPCM format assumed for sample data files with the "lpcm"
extension.

`S` corresponds to `signal.sample_type`, while `channel_count` corresponds to
`length(signal.channel_names)`.

Note that bytes (de)serialized to/from this format are little-endian (per the
Onda specification).
"""
struct LPCM{S<:LPCM_SAMPLE_TYPE_UNION} <: AbstractLPCMFormat
    channel_count::Int
end

LPCM(signal::Signal) = LPCM{signal.sample_type}(length(signal.channel_names))

format_constructor_for_file_extension(::Val{:lpcm}) = LPCM

function _validate_lpcm_samples(format::LPCM{S}, samples::AbstractMatrix) where {S}
    if format.channel_count != size(samples, 1)
        throw(ArgumentError("""
                            `samples` row count ($(size(samples, 1))) does not
                            match expected channel count ($(format.channel_count))
                            """))
    elseif !(eltype(samples) <: S)
        throw(ArgumentError("""
                            `samples` eltype ($(eltype(samples))) does not
                            match expected eltype ($S)
                            """))
    end
    return nothing
end

_bytes_per_sample(format::LPCM{S}) where {S} = sizeof(S) * format.channel_count

struct LPCMStream{S<:LPCM_SAMPLE_TYPE_UNION,I} <: AbstractLPCMStream
    format::LPCM{S}
    io::I
end

deserializing_lpcm_stream(format::LPCM, io) = LPCMStream(format, io)

serializing_lpcm_stream(format::LPCM, io) = LPCMStream(format, io)

finalize_lpcm_stream(::LPCMStream) = true

function deserialize_lpcm(format::LPCM{S}, bytes, sample_offset=0,
                          sample_count=typemax(Inf)) where {S}
    byte_start = max((format.channel_count * sample_offset) + 1, length(bytes))
    byte_end = min(format.channel_count * (sample_offset + sample_count), length(bytes))
    byte_view = view(reinterpret(S, bytes), byte_start:byte_end)
    sample_count = min(Int(length(byte_view) / _bytes_per_sample(format)), sample_count)
    return reshape(byte_view, (format.channel_count, sample_count))
end

function deserialize_lpcm(stream::LPCMStream, sample_offset=0, sample_count=typemax(Inf))
    bytes_per_sample = _bytes_per_sample(stream.format)
    jump(stream.io, bytes_per_sample * sample_offset)
    bytes = read(stream.io, bytes_per_sample * sample_count)
    return deserialize_lpcm(stream.format, bytes)
end

function serialize_lpcm(format::LPCM, samples::AbstractMatrix)
    _validate_lpcm_samples(samples, format)
    samples isa Matrix && return reinterpret(UInt8, vec(samples))
    io = IOBuffer()
    write(io, samples)
    return resize!(io.data, io.size)
end

function serialize_lpcm(stream::LPCMStream, samples::AbstractMatrix)
    _validate_lpcm_samples(stream.format, samples)
    return write(stream.io, samples)
end

#####
##### `LPCMZst`
#####

"""
    LPCMZst(lpcm::LPCM; level=3)
    LPCMZst(signal::Signal; level=3)

Return a `LPCMZst<:AbstractLPCMFormat` instance that corresponds to Onda's
default interleaved LPCM format compressed by `zstd`. This format is assumed
for sample data files with the "lpcm.zst" extension.

The `level` keyword argument sets the same compression level parameter as the
corresponding flag documented by the `zstd` command line utility.

See https://facebook.github.io/zstd/ for details about `zstd`.
"""
struct LPCMZst{S} <: AbstractLPCMFormat
    lpcm::LPCM{S}
    level::Int
    LPCMZst(lpcm::LPCM{S}; level=3) where {S} = new{S}(lpcm, level)
end

LPCMZst(signal::Signal; kwargs...) = LPCMZst(LPCM(signal); kwargs...)

format_constructor_for_file_extension(::Val{Symbol("lpcm.zst")}) = LPCMZst

function deserialize_lpcm(format::LPCMZst, bytes, args...)
    decompressed_bytes = zstd_decompress(unsafe_vec_uint8(bytes))
    return deserialize_lpcm(format.lpcm, decompressed_bytes, args...)
end

function serialize_lpcm(format::LPCMZst, samples::AbstractMatrix)
    decompressed_bytes = unsafe_vec_uint8(serialize_lpcm(format.lpcm, samples))
    return zstd_compress(bytes, format.level)
end

struct LPCMZstStream{L<:LPCMStream} <: AbstractLPCMStream
    stream::L
end

function deserializing_lpcm_stream(format::LPCMZst, io)
    stream = LPCMStream(format, ZstdDecompressorStream(io))
    return LPCMZstStream(stream)
end

function serializing_lpcm_stream(format::LPCMZst, io)
    stream = LPCMStream(format, ZstdCompressorStream(io; level=format.level))
    return LPCMZstStream(stream)
end

function finalize_lpcm_stream(stream::LPCMZstStream)
    if stream.stream.io isa ZstdCompressorStream
        # write `TranscodingStreams.TOKEN_END` instead of calling `close` since
        # `close` closes the underlying `io`, and we don't want to do that
        write(stream.stream.io, TranscodingStreams.TOKEN_END)
        flush(stream.stream.io)
        return true
    else
        close(stream.stream.io)
        return false
    end
end

deserialize_lpcm(stream::LPCMZstStream, args...) = deserialize_lpcm(stream.stream, args...)

serialize_lpcm(stream::LPCMZstStream, args...) = serialize_lpcm(stream.stream, args...)
