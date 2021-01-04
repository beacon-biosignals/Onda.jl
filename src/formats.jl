#####
##### LPCM API types/functions/stubs
#####

const LPCM_FORMAT_REGISTRY = Any[]

"""
TODO precompile issues?
"""
register_lpcm_format!(create_constructor) = push!(LPCM_FORMAT_REGISTRY, create_constructor)

"""
    format(file_format::AbstractString, signal::Signal; kwargs...)

Return `f(signal; kwargs...)` where `f` constructs the `AbstractLPCMFormat` instance that
corresponds to `file_format`. `f` is determined by matching `file_format` to a suitable
format constuctor registered via [`register_lpcm_format!`](@ref).

See also: [`deserialize_lpcm`](@ref), [`serialize_lpcm`](@ref)
"""
function format(file_format::AbstractString, signal::Signal; kwargs...)
    for create_constructor in LPCM_FORMAT_REGISTRY
        f = create_constructor(file_format)
        f === nothing && continue
        return f(signal; kwargs...)
    end
    throw(ArgumentError("unrecognized file_format: \"$file_format\""))
end

"""
    AbstractLPCMFormat

A type whose subtypes represents byte/stream formats that can be (de)serialized
to/from Onda's standard interleaved LPCM representation.

All subtypes of the form `F<:AbstractLPCMFormat` must call [`Onda.register_lpcm_format!`](@ref)
and define an appropriate [`file_format_string`](@ref) method.

See also:

- [`format`](@ref)
- [`deserialize_lpcm`](@ref)
- [`deserialize_lpcm_callback`](@ref)
- [`serialize_lpcm`](@ref)
- [`LPCM`](@ref)
- [`LPCMZst`](@ref)
- [`AbstractLPCMStream`](@ref)
"""
abstract type AbstractLPCMFormat end

"""
    AbstractLPCMStream

A type that represents an LPCM (de)serialization stream.

See also:

- [`deserializing_lpcm_stream`](@ref)
- [`serializing_lpcm_stream`](@ref)
- [`finalize_lpcm_stream`](@ref)
"""
abstract type AbstractLPCMStream end

"""
    deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)

Return `(callback, required_byte_offset, required_byte_count)` where `callback` accepts the
byte block specified by `required_byte_offset` and `required_byte_count` and returns the
samples specified by `samples_offset` and `samples_count`.

As a fallback, this function returns `(callback, missing, missing)`, where `callback`
requires all available bytes. `AbstractLPCMFormat` subtypes that support partial/block-based
deserialization (e.g. the basic `LPCM` format) can overload this function to only request
exactly the byte range that is required for the sample range requested by the caller.

This allows callers to handle the byte block retrieval themselves while keeping
Onda's LPCM Serialization API agnostic to the caller's storage layer of choice.
"""
function deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)
    callback = bytes -> deserialize_lpcm(format, bytes, samples_offset, samples_count)
    return callback, missing, missing
end

"""
    deserializing_lpcm_stream(format::AbstractLPCMFormat, io)

Return a `stream::AbstractLPCMStream` that wraps `io` to enable direct LPCM
deserialization from `io` via [`deserialize_lpcm`](@ref).

Note that `stream` must be finalized after usage via [`finalize_lpcm_stream`](@ref).
Until `stream` is finalized, `io` should be considered to be part of the internal
state of `stream` and should not be directly interacted with by other processes.
"""
function deserializing_lpcm_stream end

"""
    serializing_lpcm_stream(format::AbstractLPCMFormat, io)

Return a `stream::AbstractLPCMStream` that wraps `io` to enable direct LPCM
serialization to `io` via [`serialize_lpcm`](@ref).

Note that `stream` must be finalized after usage via [`finalize_lpcm_stream`](@ref).
Until `stream` is finalized, `io` should be considered to be part of the internal
state of `stream` and should not be directly interacted with by other processes.
"""
function serializing_lpcm_stream end

"""
    finalize_lpcm_stream(stream::AbstractLPCMStream)::Bool

Finalize `stream`, returning `true` if the underlying I/O object used to construct
`stream` is still open and usable. Otherwise, return `false` to indicate that
underlying I/O object was closed as result of finalization.
"""
function finalize_lpcm_stream end

"""
    deserialize_lpcm(format::AbstractLPCMFormat, bytes,
                     samples_offset::Integer=0,
                     samples_count::Integer=typemax(Int))
    deserialize_lpcm(stream::AbstractLPCMStream,
                     samples_offset::Integer=0,
                     samples_count::Integer=typemax(Int))

Return a channels-by-timesteps `AbstractMatrix` of interleaved LPCM-encoded
sample data by deserializing the provided `bytes` in the given `format`, or
from the given `stream` constructed by [`deserializing_lpcm_stream`](@ref).

Note that this operation may be performed in a zero-copy manner such that the
returned sample matrix directly aliases `bytes`.

The returned segment is at most `sample_offset` samples offset from the start of
`stream`/`bytes` and contains at most `sample_count` samples. This ensures that
overrun behavior is generally similar to the behavior of `Base.skip(io, n)` and
`Base.read(io, n)`.

This function is the inverse of the corresponding [`serialize_lpcm`](@ref) method, i.e.:

```
serialize_lpcm(format, deserialize_lpcm(format, bytes)) == bytes
```
"""
function deserialize_lpcm end

"""
    serialize_lpcm(format::AbstractLPCMFormat, samples::AbstractMatrix)
    serialize_lpcm(stream::AbstractLPCMStream, samples::AbstractMatrix)

Return the `AbstractVector{UInt8}` of bytes that results from serializing `samples`
to the given `format` (or serialize those bytes directly to `stream`) where `samples`
is a channels-by-timesteps matrix of interleaved LPCM-encoded sample data.

Note that this operation may be performed in a zero-copy manner such that the
returned `AbstractVector{UInt8}` directly aliases `samples`.

This function is the inverse of the corresponding [`deserialize_lpcm`](@ref)
method, i.e.:

```
deserialize_lpcm(format, serialize_lpcm(format, samples)) == samples
```
"""
function serialize_lpcm end

"""
    file_format_string(format::AbstractLPCMFormat)

Return the `String` representation of `format` to be written to the `file_format` field of a `*.signals` file.
"""
function file_format_string end

#####
##### read_lpcm/write_lpcm
#####

read_lpcm(path, format::AbstractLPCMFormat) = deserialize_lpcm(format, read(path))

function read_lpcm(path, format::AbstractLPCMFormat, sample_offset, sample_count)
    deserialize_requested_samples,
    required_byte_offset,
    required_byte_count = deserialize_lpcm_callback(format,
                                                    sample_offset,
                                                    sample_count)
    bytes = read_byte_range(path, required_byte_offset, required_byte_count)
    return deserialize_requested_samples(bytes)
end

write_lpcm(path, format::AbstractLPCMFormat, data) = write_path(path, serialize_lpcm(format, data))

#####
##### `LPCM`
#####

"""
    LPCM(channel_count::Int, sample_type::Type)
    LPCM(signal::Signal)

Return a `LPCM<:AbstractLPCMFormat` instance corresponding to Onda's default
interleaved LPCM format assumed for sample data files with the "lpcm"
extension.

`channel_count` corresponds to `length(signal.channels)`, while `sample_type`
corresponds to `signal.sample_type`

Note that bytes (de)serialized to/from this format are little-endian (per the
Onda specification).
"""
struct LPCM{S<:LPCM_SAMPLE_TYPE_UNION} <: AbstractLPCMFormat
    channel_count::Int
    sample_type::Type{S}
end

LPCM(signal::Signal) = LPCM(length(signal.channels), signal.sample_type)

register_lpcm_format!(file_format -> file_format == "lpcm" ? LPCM : nothing)

file_format_string(::LPCM) = "lpcm"

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

function deserialize_lpcm(format::LPCM{S}, bytes, sample_offset::Integer=0,
                          sample_count::Integer=typemax(Int)) where {S}
    sample_interpretation = reinterpret(S, bytes)
    sample_start = min((format.channel_count * sample_offset) + 1, length(sample_interpretation))
    sample_end = format.channel_count * (sample_offset + sample_count)
    sample_end = sample_end >= 0 ? sample_end : typemax(Int) # handle overflow
    sample_end = min(sample_end, length(sample_interpretation))
    sample_view = view(sample_interpretation, sample_start:sample_end)
    timestep_count = min(Int(length(sample_view) / format.channel_count), sample_count)
    return reshape(sample_view, (format.channel_count, timestep_count))
end

function deserialize_lpcm_callback(format::LPCM{S}, samples_offset, samples_count) where {S}
    callback = bytes -> deserialize_lpcm(format, bytes)
    bytes_per_sample = _bytes_per_sample(format)
    return callback, samples_offset * bytes_per_sample, samples_count * bytes_per_sample
end

function deserialize_lpcm(stream::LPCMStream, sample_offset::Integer=0,
                          sample_count::Integer=typemax(Int))
    bytes_per_sample = _bytes_per_sample(stream.format)
    jump(stream.io, bytes_per_sample * sample_offset)
    byte_count = bytes_per_sample * sample_count
    byte_count = byte_count >= 0 ? byte_count : typemax(Int) # handle overflow
    return deserialize_lpcm(stream.format, read(stream.io, byte_count))
end

function serialize_lpcm(format::LPCM, samples::AbstractMatrix)
    _validate_lpcm_samples(format, samples)
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

register_lpcm_format!(file_format -> file_format == "lpcm.zst" ? LPCMZst : nothing)

file_format_string(::LPCMZst) = "lpcm.zst"

function deserialize_lpcm(format::LPCMZst, bytes, args...)
    decompressed_bytes = zstd_decompress(unsafe_vec_uint8(bytes))
    return deserialize_lpcm(format.lpcm, decompressed_bytes, args...)
end

function serialize_lpcm(format::LPCMZst, samples::AbstractMatrix)
    decompressed_bytes = unsafe_vec_uint8(serialize_lpcm(format.lpcm, samples))
    return zstd_compress(decompressed_bytes, format.level)
end

struct LPCMZstStream{L<:LPCMStream} <: AbstractLPCMStream
    stream::L
end

function deserializing_lpcm_stream(format::LPCMZst, io)
    stream = LPCMStream(format.lpcm, ZstdDecompressorStream(io))
    return LPCMZstStream(stream)
end

function serializing_lpcm_stream(format::LPCMZst, io)
    stream = LPCMStream(format.lpcm, ZstdCompressorStream(io; level=format.level))
    return LPCMZstStream(stream)
end

function finalize_lpcm_stream(stream::LPCMZstStream)
    if stream.stream.io isa ZstdCompressorStream
        # write `TranscodingStreams.TOKEN_END` and change the `ZstdCompressorStream`'s
        # mode to `:close`, which flushes any remaining buffered data and finalizes the
        # underlying codec to free its resources without closing the underlying I/O object.
        write(stream.stream.io, TranscodingStreams.TOKEN_END)
        TranscodingStreams.changemode!(stream.stream.io, :close)
        return true
    else
        close(stream.stream.io)
        return false
    end
end

deserialize_lpcm(stream::LPCMZstStream, args...) = deserialize_lpcm(stream.stream, args...)

serialize_lpcm(stream::LPCMZstStream, args...) = serialize_lpcm(stream.stream, args...)
