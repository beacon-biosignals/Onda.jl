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

zstd_decompress(bytes::Vector{UInt8}) = transcode(ZstdDecompressor, bytes)

####
#### bytes/streams
####

jump(io::IO, n) = (read(io, n); nothing)
jump(io::IOStream, n) = (skip(io, n); nothing)
jump(io::IOBuffer, n) = ((io.seekable ? skip(io, n) : read(io, n)); nothing)

unsafe_vec_uint8(x::AbstractVector{UInt8}) = convert(Vector{UInt8}, x)
unsafe_vec_uint8(x::Base.ReinterpretArray{UInt8,1}) = unsafe_wrap(Vector{UInt8}, pointer(x), length(x))
