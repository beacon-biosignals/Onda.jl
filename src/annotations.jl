#####
##### validation
#####

validate_annotation_schema(::Nothing) = @warn "`schema == nothing`; skipping schema validation"

function validate_annotation_schema(schema::Tables.Schema)
    length(schema.names) >= 3 || throw(ArgumentError("invalid `Annotation` fields: need at least 3 fields, input has $(length(schema.names))"))
    for (i, (name, T)) in enumerate((:recording => Union{UInt128,UUID},
                                     :id => Union{UInt128,UUID},
                                     :span => Union{NamedTupleTimeSpan,TimeSpan}))
        schema.names[i] === name || throw(ArgumentError("invalid `Annotation` fields: field $i must be named `:$(name)`, got $(schema.names[i])"))
        schema.types[i] <: T || throw(ArgumentError("invalid `Annotation` fields: invalid `:$(name)` field type: $(schema.types[i])"))
    end
    return nothing
end

#####
##### Annotation
#####

"""
    Annotation(annotations_table_row)
    Annotation(recording, id, span; custom...)
    Annotation(; recording, id, span, custom...)

Return an `Annotation` instance that represents a row of an `*.onda.annotations.arrow` table.

The names, types, and order of the columns of an `Annotation` instance are guaranteed to
result in a `*.onda.annotations.arrow`-compliant row when written out via `write_annotations`.

This type primarily exists to aid in the validated construction of such rows/tables,
and is not intended to be used as a type constraint in function or struct definitions.
Instead, you should generally duck-type any "annotation-like" arguments/fields so that
other generic row types will compose with your code.

This type supports Tables.jl's `AbstractRow` interface (but does not subtype `AbstractRow`).
"""
struct Annotation{R}
    _row::R
    function Annotation(; recording, id, span, custom...)
        recording::UUID = recording isa UUID ? recording : UUID(recording)
        id::UUID = id isa UUID ? id : UUID(id)
        span::TimeSpan = TimeSpan(span)
        _row = (; recording, id, span, custom...)
        return new{typeof(_row)}(_row)
    end
end

Annotation(row) = Annotation(NamedTuple(Tables.Row(row)))
Annotation(row::NamedTuple) = Annotation(; row...)
Annotation(row::Annotation) = row
Annotation(recording, id, span; custom...) = Annotation(; recording, id, span, custom...)

Base.propertynames(x::Annotation) = propertynames(getfield(x, :_row))
Base.getproperty(x::Annotation, name::Symbol) = getproperty(getfield(x, :_row), name)

ConstructionBase.setproperties(x::Annotation, patch::NamedTuple) = Annotation(setproperties(getfield(x, :_row), patch))

Tables.getcolumn(x::Annotation, i::Int) = Tables.getcolumn(getfield(x, :_row), i)
Tables.getcolumn(x::Annotation, nm::Symbol) = Tables.getcolumn(getfield(x, :_row), nm)
Tables.columnnames(x::Annotation) = Tables.columnnames(getfield(x, :_row))

#####
##### read/write
#####

"""
    read_annotations(io_or_path; validate_schema::Bool=true)

Return the `*.onda.annotations.arrow`-compliant table read from `io_or_path`.

If `validate_schema` is `true`, the table's schema will be validated to ensure it is
a `*.onda.annotations.arrow`-compliant table. An `ArgumentError` will be thrown if
any schema violation is detected.
"""
function read_annotations(io_or_path; materialize::Union{Missing,Bool}=missing, validate_schema::Bool=true)
    table = read_onda_table(io_or_path)
    validate_schema && validate_annotation_schema(Tables.schema(table))
    if materialize isa Bool
        if materialize
            @warn "`read_annotations(x; materialize=true)` is deprecated; use `Onda.materialize(read_annotations(x))` instead"
            return materialize(table)
        else
            @warn "`read_annotations(x; materialize=false)` is deprecated; use `read_annotations(x)` instead"
        end
    end
    return table
end

"""
    write_annotations(io_or_path, table; kwargs...)

Write `table` to `io_or_path`, first validating that `table` is a
`*.onda.annotations.arrow`-compliant table. An `ArgumentError` will
be thrown if any schema violation is detected.

`kwargs` is forwarded to an internal invocation of `Arrow.write(...; file=true, kwargs...)`.
"""
function write_annotations(io_or_path, table; kwargs...)
    columns = Tables.columns(table)
    schema = Tables.schema(columns)
    try
        validate_annotation_schema(schema)
    catch
        @warn "Invalid schema in input `table`. Try calling `Annotation.(Tables.rows(table))` to see if it is convertible to the required schema."
        rethrow()
    end
    return write_onda_table(io_or_path, columns; kwargs...)
end

#####
##### utilities
#####

"""
    merge_overlapping_annotations(annotations)

Given the `*.onda.annotations.arrow`-compliant table `annotations`, return
a table corresponding to `annotations` except that overlapping entries have
been merged.

Specifically, two annotations `a` and `b` are determined to be "overlapping"
if `a.recording == b.recording && TimeSpans.overlaps(a.span, b.span)`. Merged
annotations' `span` fields are generated via calling `TimeSpans.shortest_timespan_containing`
on the overlapping set of source annotations.

The returned annotations table only has a single custom column named `from`
whose entries are `Vector{UUID}`s populated with the `id`s of the generated
annotations' source(s). Note that every annotation in the returned table
has a freshly generated `id` field and a non-empty `from` field, even if
the `from` only has a single element (i.e. corresponds to a single
non-overlapping annotation).

Note that this function internally works with `Tables.columns(annotations)`
rather than `annotations` directly, so it may be slower and/or require more
memory if `!Tables.columnaccess(annotations)`.
"""
function merge_overlapping_annotations(annotations)
    columns = Tables.columns(annotations)
    merged = Annotation[]
    for (rid, (locs,)) in locations((columns.recording,))
        subset = (recording=view(columns.recording, locs), id=view(columns.id, locs), span=view(columns.span, locs))
        p = sortperm(subset.span; by=TimeSpans.start)
        sorted = Tables.rows((recording=view(subset.recording, p), id=view(subset.id, p), span=view(subset.span, p)))
        init = first(sorted)
        push!(merged, Annotation(rid, uuid4(), init.span; from=[init.id]))
        for next in Iterators.drop(sorted, 1)
            prev = merged[end]
            if next.recording == prev.recording && TimeSpans.overlaps(next.span, prev.span)
                push!(prev.from, next.id)
                merged[end] = setproperties(prev; span=TimeSpans.shortest_timespan_containing((prev.span, next.span)))
            else
                push!(merged, Annotation(next.recording, uuid4(), next.span; from=[next.id]))
            end
        end
    end
    return merged
end
