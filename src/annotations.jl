#####
##### arrrrr i'm a pirate
#####

const NamedTupleTimeSpan = NamedTuple{(:start, :stop),Tuple{Nanosecond,Nanosecond}}

TimeSpans.istimespan(::NamedTupleTimeSpan) = true
TimeSpans.start(x::NamedTupleTimeSpan) = x.start
TimeSpans.stop(x::NamedTupleTimeSpan) = x.stop

#####
##### Annotation
#####

struct Annotation{R}
    _row::R
    function Annotation(_row::R) where {R}
        fields = Tables.columnnames(_row)
        length(fields) > 2 || error("invalid `Annotation` input: need at least 3 fields, has $(length(fields))")
        for (i, name) in enumerate((:recording, :id, :span))
            fields[i] == name || error("invalid `Annotation` input: field $i must be $name, got $(fields[i])")
        end
        if !(Tables.getcolumn(_row, :recording) isa Union{UInt128,UUID})
            error("invalid `Annotation` input: invalid `recording` field type")
        elseif !(Tables.getcolumn(_row, :id) isa Union{UInt128,UUID})
            error("invalid `Annotation` input: invalid `id` field type")
        elseif !(Tables.getcolumn(_row, :span) isa Union{NamedTupleTimeSpan,TimeSpan})
            error("invalid `Annotation` input: invalid `span` field type")
        end
        return new{R}(_row)
    end
end

function Annotation(recording, id, span; custom...) where {V}
    recording = recording isa UUID ? recording : UUID(recording)
    id = id isa UUID ? id : UUID(id)
    return Annotation((; recording, id, span=TimeSpan(span), custom...))
end

Annotation(; recording, id, span, custom...) = Annotation(recording, id, span; custom...)

Base.propertynames(x::Annotation) = propertynames(getfield(x, :_row))
Base.getproperty(x::Annotation, name::Symbol) = getproperty(getfield(x, :_row), name)

Tables.getcolumn(x::Annotation, i::Int) = Tables.getcolumn(getfield(x, :_row), i)
Tables.getcolumn(x::Annotation, nm::Symbol) = Tables.getcolumn(getfield(x, :_row), nm)
Tables.columnnames(x::Annotation) = Tables.columnnames(getfield(x, :_row))

function Tables.schema(::AbstractVector{A}) where {R,A<:Annotation{R}}
    isconcretetype(R) && return nothing
    return Tables.Schema(fieldnames(R), fieldtypes(R))
end

TimeSpans.istimespan(::Annotation) = true
TimeSpans.start(x::Annotation) = TimeSpans.start(x.span)
TimeSpans.stop(x::Annotation) = TimeSpans.stop(x.span)

#####
##### `*.annotations`
#####

const ANNOTATIONS_COLUMN_NAMES = (:recording, :id, :span)

const ANNOTATIONS_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},Union{NamedTupleTimeSpan,TimeSpan},Vararg{Any}}

# is_readable_annotations_schema(::Any) = false
# is_readable_annotations_schema(::Tables.Schema{ANNOTATIONS_COLUMN_NAMES,<:ANNOTATIONS_READABLE_COLUMN_TYPES}) = true

# is_writable_annotations_schema(::Any) = false
# is_writable_annotations_schema(::Tables.Schema{ANNOTATIONS_COLUMN_NAMES,<:ANNOTATIONS_WRITABLE_COLUMN_TYPES}) = true

# function read_annotations(io_or_path; materialize::Bool=false, error_on_invalid_schema::Bool=false)
#     table = read_onda_table(io_or_path; materialize)
#     invalid_schema_error_message = error_on_invalid_schema ? "schema must have names matching `Onda.ANNOTATIONS_COLUMN_NAMES` and types matching `Onda.ANNOTATIONS_COLUMN_TYPES`" : nothing
#     validate_schema(is_readable_annotations_schema, Tables.schema(table); invalid_schema_error_message)
#     return table
# end

# function write_annotations(io_or_path, table; kwargs...)
#     invalid_schema_error_message = """
#                                    schema must have names matching `Onda.ANNOTATIONS_COLUMN_NAMES` and types matching `Onda.ANNOTATIONS_COLUMN_TYPES`.
#                                    Try calling `Onda.Annotation.(Tables.rows(table))` on your `table` to see if it is convertible to the required schema.
#                                    """
#     validate_schema(is_writable_annotations_schema, Tables.schema(table); invalid_schema_error_message)
#     return write_onda_table(io_or_path, table; kwargs...)
# end