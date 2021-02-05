log(message) = @info "$(now()) | $message"

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
##### arrrrr i'm a pirate
#####

const NamedTupleTimeSpan = NamedTuple{(:start, :stop),Tuple{Nanosecond,Nanosecond}}

TimeSpans.istimespan(::NamedTupleTimeSpan) = true
TimeSpans.start(x::NamedTupleTimeSpan) = x.start
TimeSpans.stop(x::NamedTupleTimeSpan) = x.stop

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

function write_onda_table(io_or_path, table; kwargs...)
    Arrow.setmetadata!(table, Dict("onda_format_version" => "v$(MAXIMUM_ONDA_FORMAT_VERSION)"))
    Arrow.write(io_or_path, table; kwargs...)
    return columns
end

# function validate_schema(is_valid_schema, schema; invalid_schema_error_message=nothing)
#     if schema === nothing
#         message = "schema is not determinable (schema is `nothing`)"
#     elseif !is_valid_schema(schema)
#         message = "table does not have appropriate schema: $schema"
#     else
#         message = nothing
#     end
#     if message !== nothing
#         if invalid_schema_error_message === nothing
#             @warn message
#         else
#             throw(ArgumentError(message * " | " * invalid_schema_error_message))
#         end
#     end
#     return nothing
# end

"""
TODO
"""
function locations(collections::NTuple{N}) where {N}
    K = promote_type(eltype.(collections)...)
    results = Dict{K,NTuple{N,Vector{Int}}}()
    for (c, collection) in enumerate(collections)
        for (i, item) in enumerate(collection)
            push!(get!(() -> ntuple(_ -> Int[], N), results, item)[c], i)
        end
    end
    return results
end

"""
TODO
"""
function gather(column_name, tables::Vararg{Any,N}) where {N}
    cols = ntuple(i -> Tables.getcolumn(tables[i], column_name), N)
    return Dict(id => ntuple(i -> view(tables[i], locs[i], :), N) for (id, locs) in locations(cols))
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
