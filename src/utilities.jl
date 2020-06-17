####
#### validation
####

"""
    Onda.validate_on_construction()

If this function returns `true`, Onda objects will be validated upon construction
for compliance with the Onda specification.

If this function returns `false`, no such validation will be performed upon construction.

Users may interactively redefine this method in order to attempt to read malformed
Onda datasets.

Returns `true` by default.

See also: [`validate_signal`](@ref), [`validate_samples`](@ref)
"""
validate_on_construction() = true

const MINIMUM_ONDA_FORMAT_VERSION = v"0.3"

const MAXIMUM_ONDA_FORMAT_VERSION = v"0.4"

function is_supported_onda_format_version(v::VersionNumber)
    min_major, min_minor = MINIMUM_ONDA_FORMAT_VERSION.major, MINIMUM_ONDA_FORMAT_VERSION.minor
    max_major, max_minor = MAXIMUM_ONDA_FORMAT_VERSION.major, MAXIMUM_ONDA_FORMAT_VERSION.minor
    return (min_major <= v.major <= max_major) && (min_minor <= v.minor <= max_minor)
end

const ALPHANUMERIC_SNAKE_CASE_CHARACTERS = Char['_',
                                                '0':'9'...,
                                                'a':'z'...]

function is_lower_snake_case_alphanumeric(x::AbstractString, also_allow=())
    return !startswith(x, '_') && !endswith(x, '_') &&
           all(i -> i in ALPHANUMERIC_SNAKE_CASE_CHARACTERS || i in also_allow, x)
end

####
#### zstd_compress/zstd_decompress
####

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

function zstd_decompress(reader, io::IO)
    @warn """
          Streaming `zstd` decompression via `Onda.zstd_decompress(reader, io::IO)` has been shown
          to exhibit memory-leak-like  behaviors (underlying cause at time of writing is currently
          unknown).

          If you did not call this method directly, it's likely that this was reached via
          a call to  `Onda.load(dataset, uuid, signal_name, span)`. This call may be replaced
          with `Onda.load(dataset, uuid, signal_name)[:, span]`, but note that this will load
          in *all* sample data for the given signal.
          """
    reader(ZstdDecompressorStream(io))
end

####
#### bytes/streams
####

jump(io::IO, n) = (read(io, n); nothing)
jump(io::IOStream, n) = (skip(io, n); nothing)
jump(io::IOBuffer, n) = ((io.seekable ? skip(io, n) : read(io, n)); nothing)

unsafe_vec_uint8(x::AbstractVector{UInt8}) = convert(Vector{UInt8}, x)
unsafe_vec_uint8(x::Base.ReinterpretArray{UInt8,1}) = unsafe_wrap(Vector{UInt8}, pointer(x), length(x))
