module Onda

using UUIDs, Dates, Random
using MsgPack
using TranscodingStreams
using CodecZstd

const ONDA_FORMAT_VERSION = v"0.2"

#####
##### utilities
#####

function is_supported_onda_format_version(v::VersionNumber)
    onda_major, onda_minor = ONDA_FORMAT_VERSION.major, ONDA_FORMAT_VERSION.minor
    return onda_major == v.major && (onda_major != 0 || onda_minor == v.minor)
end

const ALPHANUMERIC_SNAKE_CASE_CHARACTERS = Char['_',
                                                '0':'9'...,
                                                'a':'z'...]

function is_lower_snake_case_alphanumeric(x::AbstractString, also_allow=())
    return !startswith(x, '_') && !endswith(x, '_') &&
           all(i -> i in ALPHANUMERIC_SNAKE_CASE_CHARACTERS || i in also_allow, x)
end

function zstd_compress(bytes::Vector{UInt8}, level=3)
    compressor = ZstdCompressor(; level=level)
    TranscodingStreams.initialize(compressor)
    compressed_bytes = transcode(compressor, bytes)
    TranscodingStreams.finalize(compressor)
    return compressed_bytes
end

function zstd_compress(writer, io::IO, level=3)
    stream = ZstdCompressorStream(io; level=level)
    result = writer(stream)
    # write `TranscodingStreams.TOKEN_END` instead of calling `close` since
    # `close` closes the underlying `io`, and we don't want to do that
    write(stream, TranscodingStreams.TOKEN_END)
    flush(stream)
    return result
end

zstd_decompress(bytes::Vector{UInt8}) = transcode(ZstdDecompressor, bytes)

zstd_decompress(reader, io::IO) = reader(ZstdDecompressorStream(io))

#####
##### includes/exports
#####

include("timespans.jl")
export AbstractTimeSpan, TimeSpan, contains, overlaps, shortest_timespan_containing,
       index_from_time, time_from_index, duration

include("recordings.jl")
export Recording, Signal, signal_from_template, Annotation, annotate!

include("serialization.jl")
export AbstractLPCMSerializer, serializer, deserialize_lpcm, serialize_lpcm,
       LPCM, LPCMZst

include("samples.jl")
export Samples, encode, encode!, decode, decode!, channel, channel_count, sample_count

include("dataset.jl")
export Dataset, samples_path, create_recording!, set_duration!, load, store!, delete!,
       save_recordings_file

include("printing.jl")

end # module
