module OndaRLE

using Onda
using Onda: AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCM_SAMPLE_TYPE_UNION,
            register_lpcm_format!, file_format_string,
            serialize_lpcm, deserialize_lpcm,
            serializing_lpcm_stream, deserializing_lpcm_stream, finalize_lpcm_stream,
            _validate_lpcm_samples

export RLEFormat, Varint

#####
##### Run-count encodings
#####

struct Varint end

const COUNT_ENCODING = Union{Varint,Type{UInt16},Type{UInt32}}

_max_run(::Varint) = typemax(UInt64)
_max_run(::Type{T}) where {T<:Unsigned} = UInt64(typemax(T))

function _write_count(io::IO, ::Varint, n::Unsigned)
    x = UInt64(n)
    while x >= 0x80
        write(io, UInt8((x & 0x7f) | 0x80))
        x >>= 7
    end
    write(io, UInt8(x))
    return nothing
end

_write_count(io::IO, ::Type{T}, n::Unsigned) where {T<:Unsigned} = (write(io, T(n)); nothing)

function _read_count(io::IO, ::Varint)
    n = UInt64(0)
    shift = 0
    while true
        b = read(io, UInt8)
        n |= UInt64(b & 0x7f) << shift
        (b & 0x80) == 0 && return n
        shift += 7
    end
end

_read_count(io::IO, ::Type{T}) where {T<:Unsigned} = UInt64(read(io, T))

#####
##### `RLEFormat`
#####

"""
    RLEFormat(lpcm::LPCMFormat; count_encoding=Varint())
    RLEFormat(info; count_encoding=Varint())

Run-length encoded `AbstractLPCMFormat`. Each channel is RLE-encoded
independently (so a long run on one channel is preserved even when other
channels change in the same timestep), and channel byte lengths are written
in a header so each channel can be decoded without depending on the others.

`count_encoding` controls how run lengths are encoded:

- `Varint()` (default): LEB128 unsigned. 1 byte per run for counts ≤127,
  growing as needed; no run-length cap.
- `UInt16`: fixed 2-byte little-endian count. Runs longer than 65535 are
  split across multiple records.
- `UInt32`: fixed 4-byte little-endian count.

The `file_format` string is `"lpcm.rle"` (varint), `"lpcm.rle.u16"`, or
`"lpcm.rle.u32"`.
"""
struct RLEFormat{S<:LPCM_SAMPLE_TYPE_UNION} <: AbstractLPCMFormat
    lpcm::LPCMFormat{S}
    count_encoding::COUNT_ENCODING
end

function RLEFormat(lpcm::LPCMFormat{S}; count_encoding=Varint()) where {S}
    return RLEFormat{S}(lpcm, count_encoding)
end

RLEFormat(info; kwargs...) = RLEFormat(LPCMFormat(info); kwargs...)

Onda.file_format_string(format::RLEFormat) = _file_format_string(format.count_encoding)

_file_format_string(::Varint) = "lpcm.rle"
_file_format_string(::Type{UInt16}) = "lpcm.rle.u16"
_file_format_string(::Type{UInt32}) = "lpcm.rle.u32"

function _format_constructor(file_format::AbstractString)
    file_format == "lpcm.rle"     && return info -> RLEFormat(info; count_encoding=Varint())
    file_format == "lpcm.rle.u16" && return info -> RLEFormat(info; count_encoding=UInt16)
    file_format == "lpcm.rle.u32" && return info -> RLEFormat(info; count_encoding=UInt32)
    return nothing
end

function __init__()
    register_lpcm_format!(_format_constructor)
    return nothing
end

#####
##### encode / decode
#####

function _encode_channel(io::IO, count_encoding, channel::AbstractVector{S}) where {S}
    isempty(channel) && return nothing
    cap = _max_run(count_encoding)
    current = channel[1]
    count = UInt64(1)
    @inbounds for i in 2:length(channel)
        v = channel[i]
        if v === current && count < cap
            count += 1
        else
            _write_count(io, count_encoding, count)
            write(io, current)
            current = v
            count = UInt64(1)
        end
    end
    _write_count(io, count_encoding, count)
    write(io, current)
    return nothing
end

function _decode_channel!(out::Vector{S}, io::IO, count_encoding, byte_count::Integer) where {S}
    target = position(io) + byte_count
    while position(io) < target
        count = _read_count(io, count_encoding)
        value = read(io, S)
        for _ in 1:count
            push!(out, value)
        end
    end
    position(io) == target ||
        throw(ArgumentError("RLE channel ran past its declared byte length"))
    return out
end

function Onda.serialize_lpcm(format::RLEFormat{S}, samples::AbstractMatrix) where {S}
    _validate_lpcm_samples(format.lpcm, samples)
    nch = size(samples, 1)
    channel_bufs = Vector{Vector{UInt8}}(undef, nch)
    for ch in 1:nch
        buf = IOBuffer()
        _encode_channel(buf, format.count_encoding, view(samples, ch, :))
        channel_bufs[ch] = take!(buf)
    end
    out = IOBuffer()
    write(out, UInt32(nch))
    for buf in channel_bufs
        write(out, UInt32(length(buf)))
    end
    for buf in channel_bufs
        write(out, buf)
    end
    return take!(out)
end

function Onda.deserialize_lpcm(format::RLEFormat{S}, bytes,
                               sample_offset::Integer=0,
                               sample_count::Integer=typemax(Int)) where {S}
    io = IOBuffer(bytes)
    nch = Int(read(io, UInt32))
    nch == format.lpcm.channel_count ||
        throw(ArgumentError("RLE header channel_count ($nch) does not match format ($(format.lpcm.channel_count))"))
    channel_byte_lengths = [Int(read(io, UInt32)) for _ in 1:nch]
    channels = Vector{Vector{S}}(undef, nch)
    for ch in 1:nch
        channels[ch] = _decode_channel!(S[], io, format.count_encoding, channel_byte_lengths[ch])
    end
    timestep_count = isempty(channels) ? 0 : length(channels[1])
    for ch in 2:nch
        length(channels[ch]) == timestep_count ||
            throw(ArgumentError("RLE channels decoded to inconsistent lengths"))
    end
    data = Matrix{S}(undef, nch, timestep_count)
    @inbounds for ch in 1:nch, t in 1:timestep_count
        data[ch, t] = channels[ch][t]
    end
    sample_start = min(sample_offset + 1, timestep_count + 1)
    sample_end = sample_offset + sample_count
    sample_end = sample_end >= 0 ? sample_end : typemax(Int)
    sample_end = min(sample_end, timestep_count)
    return view(data, :, sample_start:sample_end)
end

#####
##### Streams
#####
##### RLE doesn't benefit from streaming for hypnogram-sized inputs; we buffer
##### through an IOBuffer and round-trip through serialize_lpcm/deserialize_lpcm.

mutable struct RLEStream{F<:RLEFormat,I<:IO} <: AbstractLPCMStream
    format::F
    io::I
    bytes::Vector{UInt8}
    writing::Bool
end

function Onda.serializing_lpcm_stream(format::RLEFormat, io::IO)
    return RLEStream(format, io, UInt8[], true)
end

function Onda.deserializing_lpcm_stream(format::RLEFormat, io::IO)
    return RLEStream(format, io, read(io), false)
end

function Onda.serialize_lpcm(stream::RLEStream, samples::AbstractMatrix)
    stream.writing || throw(ArgumentError("stream is in deserialize mode"))
    bytes = serialize_lpcm(stream.format, samples)
    append!(stream.bytes, bytes)
    return length(bytes)
end

function Onda.deserialize_lpcm(stream::RLEStream,
                               sample_offset::Integer=0,
                               sample_count::Integer=typemax(Int))
    stream.writing && throw(ArgumentError("stream is in serialize mode"))
    return deserialize_lpcm(stream.format, stream.bytes, sample_offset, sample_count)
end

function Onda.finalize_lpcm_stream(stream::RLEStream)
    if stream.writing
        write(stream.io, stream.bytes)
    end
    return true
end

end # module
