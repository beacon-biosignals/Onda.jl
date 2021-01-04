const ANNOTATIONS_COLUMN_NAMES = (:recording_uuid, :uuid, :start_nanosecond, :stop_nanosecond, :value)

const ANNOTATIONS_COLUMN_ACCEPTABLE_SUPERTYPES = Tuple{Union{UUID,UInt128},Union{UUID,UInt128},Nanosecond,Nanosecond,Any}

struct AnnotationsRow{V}
    recording_uuid::UUID
    uuid::UUID
    start_nanosecond::Nanosecond
    stop_nanosecond::Nanosecond
    value::V
end

function AnnotationsRow(recording_uuid, uuid, start_nanosecond, stop_nanosecond, value::V) where {V}
    recording_uuid = recording_uuid isa UUID ? recording_uuid : UUID(recording_uuid)
    uuid = uuid isa UUID ? uuid : UUID(uuid)
    return AnnotationsRow{V}(recording_uuid, uuid, Nanosecond(start_nanosecond), Nanosecond(stop_nanosecond), value)
end

function AnnotationsRow(; recording_uuid, uuid, start_nanosecond, stop_nanosecond, value)
    return AnnotationsRow(recording_uuid, uuid, start_nanosecond, stop_nanosecond, value)
end

Tables.schema(::AbstractVector{A}) where {A<:AnnotationsRow} = Tables.Schema(fieldnames(A), fieldtypes(A))

TimeSpans.istimespan(::AnnotationsRow) = true
TimeSpans.start(row::AnnotationsRow) = row.start_nanosecond
TimeSpans.stop(row::AnnotationsRow) = row.stop_nanosecond

is_valid_annotations_schema(::Any) = false
is_valid_annotations_schema(::Tables.Schema{ANNOTATIONS_COLUMN_NAMES,<:ANNOTATIONS_COLUMN_ACCEPTABLE_SUPERTYPES}) = true

function read_annotations(io_or_path; materialize::Bool=false, error_on_invalid_schema::Bool=false)
    table = read_onda_table(io_or_path; materialize)
    validate_schema(is_valid_annotations_schema, Tables.schema(table); error_on_invalid_schema)
    return table
end