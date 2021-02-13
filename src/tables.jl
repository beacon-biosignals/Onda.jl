function table_has_supported_onda_format_version(table)
    m = Arrow.getmetadata(table)
    return m isa Dict && is_supported_onda_format_version(VersionNumber(get(m, "onda_format_version", v"0.0.0")))
end

# It would be better if Arrow.jl supported a generic API for nonstandard path-like types so that
# we can avoid potential intermediate copies here, but its documentation is explicit that it only
# supports `Union{IO,String}`.

read_arrow_table(io_or_path::Union{IO,String,Vector{UInt8}}) = Arrow.Table(io_or_path)
read_arrow_table(path) = read_arrow_table(read(path))

write_arrow_table(path::String, table; kwargs...) = Arrow.write(path, table; kwargs...)
write_arrow_table(io::IO, table; kwargs...) = Arrow.write(io, table; file=true, kwargs...)
write_arrow_table(path, table; kwargs...) = (io = IOBuffer(); write_arrow_table(io, table; kwargs...); write_full_path(path, take!(io)))

function read_onda_table(path; materialize::Bool=false)
    table = read_arrow_table(path)
    table_has_supported_onda_format_version(table) || error("supported `onda_format_version` not found in annotations file")
    return materialize ? map(collect, Tables.columntable(table)) : table
end

function write_onda_table(path, table; kwargs...)
    Arrow.setmetadata!(table, Dict("onda_format_version" => "v$(MAXIMUM_ONDA_FORMAT_VERSION)"))
    write_arrow_table(path, table; kwargs...)
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

"""
    gather(column_name, tables...; extract=((table, idxs) -> view(table, idxs, :)))

Return a `Dict` whose keys are the unique values of `column_name` across tables
in `tables`, and whose values are tuples of the form:

    (rows_matching_key_in_table_1, rows_matching_key_in_table_2, ...)

This function facilitates gathering rows from `tables` into a unified cross-table
index along `column_name`.

The provided `extract` function is used to extract rows from each table; it takes
as input a table and a `Vector{Int}` of row indices, and returns the corresponding
subtable. The default definition is sufficient for `DataFrames` tables.
"""
function gather(column_name, tables::Vararg{Any,N};
                extract=((table, idxs) -> view(table, idxs, :))) where {N}
    cols = ntuple(i -> Tables.getcolumn(tables[i], column_name), N)
    return Dict(id => ntuple(i -> extract(tables[i], locs[i]), N) for (id, locs) in locations(cols))
end
