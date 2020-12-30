#####
##### validation
#####

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

const MINIMUM_ONDA_FORMAT_VERSION = v"0.5"

const MAXIMUM_ONDA_FORMAT_VERSION = v"0.5"

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

#####
##### tables
#####

function table_has_supported_onda_format_version(table)
    m = Arrow.getmetadata(table)
    return m isa Dict && is_supported_onda_format_version(VersionNumber(get(m, "onda_format_version", v"0.0.0")))
end

function read_onda_table(io_or_path; materialize::Bool=false)
    table = Arrow.Table(io_or_path)
    table_has_supported_onda_format_version(table) || error("supported `onda_format_version` not found in annotations file")
    return materialize ? map(collect, Tables.columntable(table)) : table
end

#####
##### zstd_compress/zstd_decompress
#####

function zstd_compress(bytes::Vector{UInt8}, level=3)
    compressor = ZstdCompressor(; level=level)
    TranscodingStreams.initialize(compressor)
    compressed_bytes = transcode(compressor, bytes)
    TranscodingStreams.finalize(compressor)
    return compressed_bytes
end

zstd_decompress(bytes::Vector{UInt8}) = transcode(ZstdDecompressor, bytes)

#####
##### Julia DataType <--> Onda `sample_type` string
#####

const LPCM_SAMPLE_TYPE_UNION = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,Float32,Float64}

function julia_type_from_onda_sample_type(t::AbstractString)
    t == "int8" && return Int8
    t == "int16" && return Int16
    t == "int32" && return Int32
    t == "int64" && return Int64
    t == "uint8" && return UInt8
    t == "uint16" && return UInt16
    t == "uint32" && return UInt32
    t == "uint64" && return UInt64
    t == "float32" && return Float32
    t == "float64" && return Float64
    throw(ArgumentError("sample type $t is not supported by Onda"))
end

function onda_sample_type_from_julia_type(T::Type)
    T === Int8 && return "int8"
    T === Int16 && return "int16"
    T === Int32 && return "int32"
    T === Int64 && return "int64"
    T === UInt8 && return "uint8"
    T === UInt16 && return "uint16"
    T === UInt32 && return "uint32"
    T === UInt64 && return "uint64"
    T === Float32 && return "float32"
    T === Float64 && return "float64"
    throw(ArgumentError("sample type $T is not supported by Onda"))
end

#####
##### utility functions for values with a `channels` field
#####

"""
    channel(x, name)

Return `i` where `x.channels[i] == name`.
"""
channel(x, name) = findfirst(isequal(name), x.channels)

"""
    channel(x, i::Integer)

Return `x.channels[i]`.
"""
channel(x, i::Integer) = x.channels[i]

"""
    channel_count(x)

Return `length(x.channels)`.
"""
channel_count(x) = length(x.channels)

#####
##### read/write/bytes/streams
#####

jump(io::IO, n) = (read(io, n); nothing)
jump(io::IOStream, n) = (skip(io, n); nothing)
jump(io::IOBuffer, n) = ((io.seekable ? skip(io, n) : read(io, n)); nothing)

unsafe_vec_uint8(x::AbstractVector{UInt8}) = convert(Vector{UInt8}, x)
unsafe_vec_uint8(x::Base.ReinterpretArray{UInt8,1}) = unsafe_wrap(Vector{UInt8}, pointer(x), length(x))

"""
    read_byte_range(path, byte_offset, byte_count)

Return the equivalent `read(path)[(byte_offset + 1):(byte_offset + byte_count)]`,
but try to avoid reading unreturned intermediate bytes. Note that the
effectiveness of this method depends on the type of `path`.
"""
function read_byte_range(path, byte_offset, byte_count)
    return open(path, "r") do io
        jump(io, byte_offset)
        return read(io, byte_count)
    end
end

read_byte_range(path, ::Missing, ::Missing) = read(path)

write_path(path, bytes) = (mkpath(dirname(path)); write(path, bytes))
