struct Annotation{V}
    recording::UUID
    id::UUID
    span::TimeSpan
    value::V
end

function Annotation(recording, id, span, value::V) where {V}
    recording = recording isa UUID ? recording : UUID(recording)
    id = id isa UUID ? id : UUID(id)
    return Annotation{V}(recording, id, TimeSpan(span), value)
end

Annotation(; recording, id, span, value) = Annotation(recording, id, span, value)
Annotation(x) = Annotation(x.recording, x.id, x.span, x.value)

Tables.schema(::AbstractVector{A}) where {A<:Annotation} = Tables.Schema(fieldnames(A), fieldtypes(A))

TimeSpans.istimespan(::Annotation) = true
TimeSpans.start(x::Annotation) = TimeSpans.start(x.span)
TimeSpans.stop(x::Annotation) = TimeSpans.stop(x.span)

const ANNOTATIONS_COLUMN_NAMES = (:recording, :id, :span, :value)

const ANNOTATIONS_READABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},Any,Any}

const ANNOTATIONS_WRITABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},TimeSpan,Any}

is_readable_annotations_schema(::Any) = false
is_readable_annotations_schema(::Tables.Schema{ANNOTATIONS_COLUMN_NAMES,<:ANNOTATIONS_READABLE_COLUMN_TYPES}) = true

is_writable_annotations_schema(::Any) = false
is_writable_annotations_schema(::Tables.Schema{ANNOTATIONS_COLUMN_NAMES,<:ANNOTATIONS_WRITABLE_COLUMN_TYPES}) = true

function read_annotations(io_or_path; materialize::Bool=false, error_on_invalid_schema::Bool=false)
    table = read_onda_table(io_or_path; materialize)
    invalid_schema_error_message = error_on_invalid_schema ? "schema must have names matching `Onda.ANNOTATIONS_COLUMN_NAMES` and types matching `Onda.ANNOTATIONS_COLUMN_TYPES`" : nothing
    validate_schema(is_readable_annotations_schema, Tables.schema(table); invalid_schema_error_message)
    return table
end

function write_annotations(io_or_path, table; kwargs...)
    invalid_schema_error_message = """
                                   schema must have names matching `Onda.ANNOTATIONS_COLUMN_NAMES` and types matching `Onda.ANNOTATIONS_COLUMN_TYPES`.
                                   Try calling `Onda.Annotation.(Tables.rows(table))` on your `table` to see if it is convertible to the required schema.
                                   """
    validate_schema(is_writable_annotations_schema, Tables.schema(table); invalid_schema_error_message)
    return write_onda_table(io_or_path, table; kwargs...)
end