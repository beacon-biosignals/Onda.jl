struct Annotation{V}
    recording_uuid::UUID
    uuid::UUID
    start::Nanosecond
    stop::Nanosecond
    value::V
end

function Annotation(recording_uuid, uuid, start, stop, value::V) where {V}
    recording_uuid = recording_uuid isa UUID ? recording_uuid : UUID(recording_uuid)
    uuid = uuid isa UUID ? uuid : UUID(uuid)
    return Annotation{V}(recording_uuid, uuid, Nanosecond(start), Nanosecond(stop), value)
end

Annotation(; recording_uuid, uuid, start, stop, value) = Annotation(recording_uuid, uuid, start, stop, value)
Annotation(x) = Annotation(x.recording_uuid, x.uuid, x.start, x.stop, x.value)

Tables.schema(::AbstractVector{A}) where {A<:Annotation} = Tables.Schema(fieldnames(A), fieldtypes(A))

TimeSpans.istimespan(::Annotation) = true
TimeSpans.start(x::Annotation) = x.start
TimeSpans.stop(x::Annotation) = x.stop

const ANNOTATIONS_COLUMN_NAMES = (:recording_uuid, :uuid, :start, :stop, :value)

const ANNOTATIONS_READABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},Period,Period,Any}

const ANNOTATIONS_WRITABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},Nanosecond,Nanosecond,Any}

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