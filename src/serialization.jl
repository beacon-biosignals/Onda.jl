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
##### `AbstractLPCMSerializer`
#####

"""
    AbstractLPCMSerializer

A type whose subtypes support:

- [`deserialize_lpcm`](@ref)
- [`serialize_lpcm`](@ref)

All definitions of subtypes of the form `S<:AbstractLPCMSerializer` must also support
a constructor of the form `S(::Signal)` and overload `Onda.serializer_constructor_for_file_extension`
with the appropriate file extension.

See also: [`serializer`](@ref), [`LPCM`](@ref), [`LPCMZst`](@ref)
"""
abstract type AbstractLPCMSerializer end

"""
    Onda.serializer_constructor_for_file_extension(::Val{:extension_symbol})

Return a constructor of the form `S(::Signal)::AbstractLPCMSerializer`
corresponding to the provided extension.

This function should be overloaded for new `AbstractLPCMSerializer` subtypes.
"""
function serializer_constructor_for_file_extension(::Val{unknown}) where {unknown}
    throw(ArgumentError("unknown file extension: $unknown"))
end

function register_file_extension_for_serializer(extension::Symbol, T::Type{<:AbstractLPCMSerializer})
    error("""
          `Onda.register_file_extension_for_serializer(ext, T)` is deprecated; instead, `AbstractLPCMSerializer`
          authors should define `Onda.serializer_constructor_for_file_extension(::Val{ext}) = T`.
          """)
end

"""
    serializer(signal::Signal; kwargs...)

Return `S(signal; kwargs...)` where `S` is the `AbstractLPCMSerializer` that
corresponds to `signal.file_extension` (as determined by the serializer author
via `serializer_constructor_for_file_extension`).

See also: [`deserialize_lpcm`](@ref), [`serialize_lpcm`](@ref)
"""
function serializer(signal::Signal; kwargs...)
    T = serializer_constructor_for_file_extension(Val(signal.file_extension))
    return T(signal; kwargs...)
end

"""
    deserialize_lpcm(bytes, serializer::AbstractLPCMSerializer)

Return a channels-by-timesteps `AbstractMatrix` of interleaved LPCM-encoded
sample data by deserializing the provided `bytes` from the given `serializer`.

Note that this operation may be performed in a zero-copy manner such that the
returned sample matrix directly aliases `bytes`.

This function is the inverse of the corresponding [`serialize_lpcm`](@ref)
method, i.e.:

```
serialize_lpcm(deserialize_lpcm(bytes, serializer), serializer) == bytes
```

    deserialize_lpcm(bytes, serializer::AbstractLPCMSerializer, sample_offset, sample_count)

Similar to `deserialize_lpcm(bytes, serializer)`, but deserialize only the segment requested
via `sample_offset` and `sample_count`.

    deserialize_lpcm(io::IO, serializer::AbstractLPCMSerializer[, sample_offset, sample_count])

Similar to the corresponding `deserialize_lpcm(bytes, ...)` methods, but the bytes
to be deserialized are read directly from `io`.

If `sample_offset`/`sample_count` is provided and `io`/`serializer` support
seeking, implementations of this method may read only the bytes required to
extract the requested segment instead of reading the entire stream.
"""
function deserialize_lpcm end

"""
    serialize_lpcm(samples::AbstractMatrix, serializer::AbstractLPCMSerializer)

Return the `AbstractVector{UInt8}` of bytes that results from serializing `samples`
to the given `serializer`, where `samples` is a channels-by-timesteps matrix of
interleaved LPCM-encoded sample data.

Note that this operation may be performed in a zero-copy manner such that the
returned `AbstractVector{UInt8}` directly aliases `samples`.

This function is the inverse of the corresponding [`deserialize_lpcm`](@ref)
method, i.e.:

```
deserialize_lpcm(serialize_lpcm(samples, serializer), serializer) == samples
```

    serialize_lpcm(io::IO, samples::AbstractMatrix, serializer::AbstractLPCMSerializer)

Similar to the corresponding `serialize_lpcm(samples, serializer)` method, but serializes
directly to `io`.
"""
function serialize_lpcm end

# TODO: document `deserialize_lpcm_callback`

#####
##### fallback implementations
#####

function deserialize_lpcm_callback(serializer::AbstractLPCMSerializer, samples_offset, samples_count)
    callback = bytes -> deserialize_lpcm(bytes, serializer, samples_offset, samples_count)
    return callback, missing, missing
end

function deserialize_lpcm(bytes, serializer::AbstractLPCMSerializer, args...)
    return deserialize_lpcm(IOBuffer(bytes), serializer, args...)
end

function serialize_lpcm(samples::AbstractMatrix, serializer::AbstractLPCMSerializer)
    io = IOBuffer()
    serialize_lpcm(io, samples, serializer)
    return resize!(io.data, io.size)
end

#####
##### `LPCM`
#####

const LPCM_SAMPLE_TYPE_UNION = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64}

"""
    LPCM{S}(channel_count)
    LPCM(signal::Signal)

Return a `LPCM<:AbstractLPCMSerializer` instance corresponding to Onda's default
interleaved LPCM format assumed for signal files with the ".lpcm" extension.

`S` corresponds to `signal.sample_type`, while `channel_count` corresponds to
`signal.channel_names`.

Note that bytes (de)serialized via this serializer are little-endian per the
Onda specification.
"""
struct LPCM{S<:LPCM_SAMPLE_TYPE_UNION} <: AbstractLPCMSerializer
    channel_count::Int
end

LPCM(signal::Signal) = LPCM{signal.sample_type}(length(signal.channel_names))

serializer_constructor_for_file_extension(::Val{:lpcm}) = LPCM

function deserialize_lpcm(bytes, serializer::LPCM{S}) where {S}
    sample_count = Int(length(bytes) / sizeof(S) / serializer.channel_count)
    return deserialize_lpcm(bytes, serializer, 0, sample_count)
end

function deserialize_lpcm(bytes, serializer::LPCM{S}, sample_offset, sample_count) where {S}
    i = (serializer.channel_count * sample_offset) + 1
    j = serializer.channel_count * (sample_offset + sample_count)
    return reshape(view(reinterpret(S, bytes), i:j), (serializer.channel_count, sample_count))
end

deserialize_lpcm(io::IO, serializer::LPCM) = deserialize_lpcm(read(io), serializer)

function deserialize_lpcm_callback(serializer::LPCM{S}, samples_offset, samples_count) where {S}
    callback = bytes -> deserialize_lpcm(bytes, serializer)
    bytes_per_sample = sizeof(S) * serializer.channel_count
    return callback, samples_offset * bytes_per_sample, samples_count * bytes_per_sample
end

function deserialize_lpcm(io::IO, serializer::LPCM{S}, sample_offset, sample_count) where {S}
    bytes_per_sample = sizeof(S) * serializer.channel_count
    jump(io, bytes_per_sample * sample_offset)
    return deserialize_lpcm(read(io, bytes_per_sample * sample_count), serializer)
end

function _validate_lpcm_samples(samples::AbstractMatrix{S}, serializer::LPCM{S}) where {S}
    serializer.channel_count == size(samples, 1) && return nothing
    throw(ArgumentError("`samples` row count does not match expected channel count"))
end

function serialize_lpcm(io::IO, samples::AbstractMatrix, serializer::LPCM)
    _validate_lpcm_samples(samples, serializer)
    return write(io, samples)
end

function serialize_lpcm(samples::Matrix, serializer::LPCM)
    _validate_lpcm_samples(samples, serializer)
    return reinterpret(UInt8, vec(samples))
end

#####
##### `LPCMZst`
#####

"""
    LPCMZst(lpcm::LPCM; level=3)
    LPCMZst(signal::Signal; level=3)

Return a `LPCMZst<:AbstractLPCMSerializer` instance that corresponds to
Onda's default interleaved LPCM format compressed by `zstd`. This serializer
is assumed for signal files with the ".lpcm.zst" extension.

The `level` keyword argument sets the same compression level parameter as the
corresponding flag documented by the `zstd` command line utility.

See https://facebook.github.io/zstd/ for details about `zstd`.
"""
struct LPCMZst{S} <: AbstractLPCMSerializer
    lpcm::LPCM{S}
    level::Int
    LPCMZst(lpcm::LPCM{S}; level=3) where {S} = new{S}(lpcm, level)
end

LPCMZst(signal::Signal; kwargs...) = LPCMZst(LPCM(signal); kwargs...)

serializer_constructor_for_file_extension(::Val{Symbol("lpcm.zst")}) = LPCMZst

function deserialize_lpcm(bytes, serializer::LPCMZst, args...)
    bytes = unsafe_vec_uint8(bytes)
    return deserialize_lpcm(zstd_decompress(bytes), serializer.lpcm, args...)
end

function deserialize_lpcm(io::IO, serializer::LPCMZst, args...)
    reader = io -> deserialize_lpcm(io, serializer.lpcm, args...)
    return zstd_decompress(reader, io)
end

function serialize_lpcm(samples::AbstractMatrix, serializer::LPCMZst)
    bytes = serialize_lpcm(samples, serializer.lpcm)
    return zstd_compress(unsafe_vec_uint8(bytes), serializer.level)
end

function serialize_lpcm(io::IO, samples::AbstractMatrix, serializer::LPCMZst)
    writer = io -> serialize_lpcm(io, samples, serializer.lpcm)
    return zstd_compress(writer, io, serializer.level)
end
