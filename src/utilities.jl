log(message) = @info "$(now()) | $message"

#####
##### validation
#####

"""
    Onda.validate_on_construction()

Returns `true` by default.

If this function returns `true`, various Onda objects will be validated upon construction
for compliance with the Onda specification.

Users may interactively redefine this method to `false` in order to disable this extra layer
validation, which can be useful when working with malformed Onda datasets.

See also: [`Onda.validate`](@ref)
"""
validate_on_construction() = true

const MINIMUM_ONDA_FORMAT_VERSION = v"0.5"

const MAXIMUM_ONDA_FORMAT_VERSION = v"0.5"

function is_supported_version(v::VersionNumber, lo::VersionNumber, hi::VersionNumber)
    lo_major, lo_minor = lo.major, lo.minor
    hi_major, hi_minor = hi.major, hi.minor
    return (lo_major <= v.major <= hi_major) && (lo_minor <= v.minor <= hi_minor)
end

is_supported_onda_format_version(v::VersionNumber) = is_supported_version(v, MINIMUM_ONDA_FORMAT_VERSION, MAXIMUM_ONDA_FORMAT_VERSION)

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
# The Onda Format defines `span` elements to correspond to the Arrow-equivalent of `(start=Nanosecond(...), stop=Nanosecond(...))`.
# Here we define the generic `TimeSpans` interface on this type in order to ensure that this structure can be treated like a
# `TimeSpan` anywhere. This way, callers don't need to do any fiddling if e.g. they're working with an Onda file written from
# a source that wasn't using `TimeSpans` (e.g. if it was written out by a non-Julia process).

const NamedTupleTimeSpan = NamedTuple{(:start, :stop),Tuple{Nanosecond,Nanosecond}}

TimeSpans.istimespan(::NamedTupleTimeSpan) = true
TimeSpans.start(x::NamedTupleTimeSpan) = x.start
TimeSpans.stop(x::NamedTupleTimeSpan) = x.stop

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

write_full_path(path::AbstractString, bytes) = (mkpath(dirname(path)); write(path, bytes))
write_full_path(path, bytes) = write(path, bytes)

#####
##### tables
#####

function assign_to_table_metadata!(table, pairs)
    m = Arrow.getmetadata(table)
    m = m isa Dict ? m : Dict{String,String}()
    for (k, v) in pairs
        m[k] = v
    end
    Arrow.setmetadata!(table, m)
    return table
end

function table_has_metadata(predicate, table)
    m = Arrow.getmetadata(table)
    return m isa Dict && predicate(m)
end

table_has_required_onda_metadata(table) = table_has_metadata(m -> is_supported_onda_format_version(VersionNumber(get(m, "onda_format_version", v"0.0.0"))),
                                                             table)

# It would be better if Arrow.jl supported a generic API for nonstandard path-like types so that
# we can avoid potential intermediate copies here, but its documentation is explicit that it only
# supports `Union{IO,String}`.

read_arrow_table(io_or_path::Union{IO,String,Vector{UInt8}}) = Arrow.Table(io_or_path)
read_arrow_table(path) = read_arrow_table(read(path))

write_arrow_table(path::String, table; kwargs...) = Arrow.write(path, table; kwargs...)
write_arrow_table(io::IO, table; kwargs...) = Arrow.write(io, table; file=true, kwargs...)
write_arrow_table(path, table; kwargs...) = (io = IOBuffer(); write_arrow_table(io, table; kwargs...); write_full_path(path, take!(io)))

function read_onda_table(path)
    table = read_arrow_table(path)
    if !table_has_required_onda_metadata(table)
        throw(ArgumentError("required Onda metadata not found in Arrow file; use `Onda.read_arrow_table` to read the file without this validation check"))
    end
    return table
end

function write_onda_table(path, table; kwargs...)
    assign_to_table_metadata!(columns, ("onda_format_version" => "v$(MAXIMUM_ONDA_FORMAT_VERSION)",))
    write_arrow_table(path, columns; kwargs...)
    return table
end

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

function _iterator_for_column(table, c)
    Tables.columnaccess(table) && return Tables.getcolumn(Tables.columns(table), c)
    # there's not really a need to actually materialize this iterable
    # for the caller, but doing so allows the caller to more usefully
    # employ `eltype` on this function's output (since e.g. a generator
    # would just return `Any` for the eltype)
    return [Tables.getcolumn(r, c) for r in Tables.rows(table)]
end

"""
    gather(column_name, tables...; extract=((table, idxs) -> view(table, idxs, :)))

Gather rows from `tables` into a unified cross-table index along `column_name`. Returns
a `Dict` whose keys are the unique values of `column_name` across `tables`, and whose
values are tuples of the form:

    (rows_matching_key_in_table_1, rows_matching_key_in_table_2, ...)

The provided `extract` function is used to extract rows from each table; it takes
as input a table and a `Vector{Int}` of row indices, and returns the corresponding
subtable. The default definition is sufficient for `DataFrames` tables.

Note that this function may internally call `Tables.columns` on each input table, so
it may be slower and/or require more memory if `any(!Tables.columnaccess, tables)`.
"""
function gather(column_name, tables::Vararg{Any,N};
                extract=((cols, idxs) -> view(cols, idxs, :))) where {N}
    iters = ntuple(i -> _iterator_for_column(tables[i], column_name), N)
    return Dict(id => ntuple(i -> extract(tables[i], locs[i]), N) for (id, locs) in locations(iters))
end

"""
    materialize(table)

Return a fully deserialized copy of `table`.

This function is useful when `table` has built-in deserialize-on-access or
conversion-on-access behavior (like `Arrow.Table`) and you'd like to pay
such access costs upfront before repeatedly accessing the table. For example:

```
julia> annotations = read_annotations(path_to_annotations_file);

# iterate through all elements of `annotations.span`
julia> @time foreach(identity, (span for span in annotations.span));
0.000126 seconds (306 allocations: 6.688 KiB)

julia> materialized = Onda.materialize(annotations);

julia> @time foreach(identity, (span for span in materialized.span));
  0.000014 seconds (2 allocations: 80 bytes)
```
"""
materialize(table) = map(collect, Tables.columntable(table))