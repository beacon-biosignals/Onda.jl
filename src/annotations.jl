
#####
##### validation
#####

# manually unrolling the accesses here seems to enable better constant propagation
@inline function _validate_annotation_fields(names, types)
    names[1] === :recording || throw(ArgumentError("invalid `Annotation` fields: field 1 must be named `:recording`, got $(names[1])"))
    names[2] === :id || throw(ArgumentError("invalid `Annotation` fields: field 2 must be named `:id`, got $(names[2])"))
    names[3] === :span || throw(ArgumentError("invalid `Annotation` fields: field 3 must be named `:span`, got $(names[3])"))
    types[1] <: Union{UInt128,UUID} || throw(ArgumentError("invalid `Annotation` fields: invalid `:recording` field type: $(types[1])"))
    types[2] <: Union{UInt128,UUID} || throw(ArgumentError("invalid `Annotation` fields: invalid `:id` field type: $(types[2])"))
    types[3] <: Union{NamedTupleTimeSpan,TimeSpan} || throw(ArgumentError("invalid `Annotation` fields: invalid `:span` field type: $(types[3])"))
    return nothing
end

@inline _validate_annotation_field_count(n) = n >= 3 || throw(ArgumentError("invalid `Annotation` fields: need at least 3 fields, input has $n"))

function validate_annotation_row(row)
    names = Tables.columnnames(row)
    _validate_annotation_field_count(length(names))
    types = (typeof(Tables.getcolumn(row, 1)), typeof(Tables.getcolumn(row, 2)), typeof(Tables.getcolumn(row, 3)))
    _validate_annotation_fields(names, types)
    return nothing
end

validate_annotation_schema(::Nothing) = @warn "`schema == nothing`; skipping schema validation"

function validate_annotation_schema(schema::Tables.Schema)
    _validate_annotation_field_count(length(schema.names))
    _validate_annotation_fields(schema.names, schema.types)
    return nothing
end

#####
##### Annotation
#####

struct Annotation{R}
    _row::R
    function Annotation(_row::R) where {R}
        validate_annotation_row(_row)
        return new{R}(_row)
    end
    function Annotation(recording, id, span; custom...)
        recording = recording isa UUID ? recording : UUID(recording)
        id = id isa UUID ? id : UUID(id)
        _row = (; recording, id, span=TimeSpan(span), custom...)
        return new{typeof(_row)}(_row)
    end
end

Annotation(; recording, id, span, custom...) = Annotation(recording, id, span; custom...)

Base.propertynames(x::Annotation) = propertynames(getfield(x, :_row))
Base.getproperty(x::Annotation, name::Symbol) = getproperty(getfield(x, :_row), name)

ConstructionBase.setproperties(x::Annotation, patch::NamedTuple) = Annotation(setproperties(getfield(x, :_row), patch))

Tables.getcolumn(x::Annotation, i::Int) = Tables.getcolumn(getfield(x, :_row), i)
Tables.getcolumn(x::Annotation, nm::Symbol) = Tables.getcolumn(getfield(x, :_row), nm)
Tables.columnnames(x::Annotation) = Tables.columnnames(getfield(x, :_row))

TimeSpans.istimespan(::Annotation) = true
TimeSpans.start(x::Annotation) = TimeSpans.start(x.span)
TimeSpans.stop(x::Annotation) = TimeSpans.stop(x.span)

#####
##### read/write
#####

function read_annotations(io_or_path; materialize::Bool=false, validate_schema::Bool=true)
    table = read_onda_table(io_or_path; materialize)
    validate_schema && validate_annotation_schema(Tables.schema(table))
    return table
end

function write_annotations(io_or_path, table; kwargs...)
    columns = Tables.columns(table)
    schema = Tables.schema(columns)
    try
        validate_annotation_schema(schema)
    catch
        @warn "Invalid schema in input `table`. Try calling `Onda.Annotation.(Tables.rows(table))` to see if it is convertible to the required schema."
        rethrow()
    end
    return write_onda_table(io_or_path, columns; kwargs...)
end

#####
##### utilities
#####

function merge_overlapping(annotations)
    columns = Tables.columns(annotations)
    perm = sortperm(columns.span, by=TimeSpans.start)
    sorted = Tables.rows((recording=view(columns.recording, perm), id=view(columns.id, perm), span=view(columns.span, perm)))
    init = first(sorted)
    merged = [Annotation(init.recording, uuid4(), init.span; from=[init.id])]
    for next in Iterators.drop(sorted, 1)
        prev = merged[end]
        if TimeSpans.overlaps(next.span, prev.span)
            push!(prev.from, next.id)
            merged[end] = setproperties(prev, span=TimeSpans.shortest_timespan_containing((prev.span, next.span)))
        else
            push!(merged, Annotation(next.recording, uuid4(), next.span; from=[next.id]))
        end
    end
    return merged
end