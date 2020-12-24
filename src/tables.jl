#####
##### Signals
#####

struct Signal{R} <: Tables.AbstractRow
    _row::R
end

const SIGNAL_FIELDS = NamedTuple{(:recording_uuid, :type, :file_path, :file_metadata, :channel_names, :start_nanosecond, :stop_nanosecond, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate),
                                  Tuple{UUID,String,String,Union{Missing,Nothing,Dict{String,String}},Vector{String},Nanosecond,Nanosecond,String,Float64,Float64,String,Float64}}

function Signal(; recording_uuid::UUID,
                type,
                file_path,
                file_metadata::Union{Missing,Nothing,Dict{String,String}}=nothing,
                channel_names,
                start_nanosecond,
                stop_nanosecond,
                sample_unit,
                sample_resolution_in_unit,
                sample_offset_in_unit,
                sample_type,
                sample_rate)
    return Signal{SIGNAL_FIELDS}((; recording_uuid,
                                  type=String(type),
                                  file_path=String(file_path),
                                  file_metadata,
                                  channel_names=convert(Vector{String}, channel_names),
                                  start_nanosecond=Nanosecond(start_nanosecond),
                                  stop_nanosecond=Nanosecond(stop_nanosecond),
                                  sample_unit=String(sample_unit),
                                  sample_resolution_in_unit=Float64(sample_resolution_in_unit),
                                  sample_offset_in_unit=Float64(sample_offset_in_unit),
                                  sample_type=String(sample_type),
                                  sample_rate=Float64(sample_rate)))
end

Base.propertynames(::Signal) = fieldnames(SIGNAL_FIELDS)
Base.getproperty(signal::Signal, name::Symbol) = getproperty(getfield(signal, :_row), name)::fieldtype(SIGNAL_FIELDS, name)
Tables.columnnames(::Signal) = fieldnames(SIGNAL_FIELDS)
Tables.getcolumn(signal::Signal, i::Int) = Tables.getcolumn(getfield(signal, :_row), i)::fieldtype(SIGNAL_FIELDS, i)
Tables.getcolumn(signal::Signal, nm::Symbol) = Tables.getcolumn(getfield(signal, :_row), nm)::fieldtype(SIGNAL_FIELDS, nm)
Tables.getcolumn(signal::Signal, ::Type{T}, i::Int, nm::Symbol) where {T} = Tables.getcolumn(getfield(signal, :_row), T, i, nm)::fieldtype(SIGNAL_FIELDS, i)
Tables.schema(::AbstractVector{<:Signal}) = Tables.Schema(fieldnames(SIGNAL_FIELDS), fieldtypes(SIGNAL_FIELDS))

is_valid_signals_schema(::Nothing) = true
is_valid_signals_schema(::Tables.Schema) = false
is_valid_signals_schema(::Tables.Schema{fieldnames(SIGNAL_FIELDS),<:Tuple{fieldtypes(SIGNAL_FIELDS)...}}) = true

struct Signals{C} <: Tables.AbstractColumns
    _columns::C
    function Signals(_columns::C) where {C}
        schema = Tables.schema(_columns)
        is_valid_signals_schema(schema) || throw(ArgumentError("_table does not have appropriate Signals schema: $schema"))
        return new{C}(_columns)
    end
end

Signals() = Signals(Tables.columntable(SIGNAL_FIELDS[]))

Tables.istable(signals::Signals) = Tables.istable(getfield(signals, :_columns))
Tables.schema(signals::Signals) = Tables.schema(getfield(signals, :_columns))
Tables.materializer(signals::Signals) = Tables.materializer(getfield(signals, :_columns))
Tables.rowaccess(signals::Signals) = Tables.rowaccess(getfield(signals, :_columns))
Tables.rows(signals::Signals) = (Signal(row) for row in Tables.rows(getfield(signals, :_columns)))
Tables.columnaccess(signals::Signals) = Tables.columnaccess(getfield(signals, :_columns))
Tables.columns(signals::Signals) = Tables.columns(getfield(signals, :_columns))
Tables.columnnames(signals::Signals) = Tables.columnnames(getfield(signals, :_columns))
Tables.getcolumn(signals::Signals, i::Int) = Tables.getcolumn(getfield(signals, :_columns), i)
Tables.getcolumn(signals::Signals, nm::Symbol) = Tables.getcolumn(getfield(signals, :_columns), nm)
Tables.getcolumn(signals::Signals, ::Type{T}, i::Int, nm::Symbol) where {T} = Tables.getcolumn(getfield(signals, :_columns), T, i, nm)

#####
##### Annotations
#####

struct Annotation{V,R} <: Tables.AbstractRow
    _row::R
end

_annotation_fields(::Type{V}) where {V} = NamedTuple{(:recording_uuid, :uuid, :start_nanosecond, :stop_nanosecond, :value),Tuple{UUID,UUID,Nanosecond,Nanosecond,V}}

Annotation(_row::R) where {R} = Annotation{fieldtype(R, :value),R}(_row)
Annotation{V}(_row::R) where {V,R} = Annotation{V,R}(_row)

function Annotation{V}(; recording_uuid::UUID, uuid::UUID, start_nanosecond, stop_nanosecond, value) where {V}
    return Annotation{V,_annotation_fields(V)}((; recording_uuid, uuid,
                                                start_nanosecond=Nanosecond(start_nanosecond),
                                                stop_nanosecond=Nanosecond(stop_nanosecond),
                                                value=convert(V, value)))
end

function Annotation(; recording_uuid, uuid, start_nanosecond, stop_nanosecond, value::V) where {V}
    return Annotation{V}(; recording_uuid, uuid, start_nanosecond, stop_nanosecond, value)
end

Base.propertynames(::Annotation) = fieldnames(_annotation_fields(Any))
Base.getproperty(annotation::Annotation{V}, name::Symbol) where {V} = getproperty(getfield(annotation, :_row), name)::fieldtype(_annotation_fields(V), name)
Tables.columnnames(::Annotation) = fieldnames(_annotation_fields(Any))
Tables.getcolumn(ann::Annotation{V}, i::Int) where {V} = Tables.getcolumn(getfield(ann, :_row), i)::fieldtype(_annotation_fields(V), i)
Tables.getcolumn(ann::Annotation{V}, nm::Symbol) where {V} = Tables.getcolumn(getfield(ann, :_row), nm)::fieldtype(_annotation_fields(V), nm)
Tables.getcolumn(ann::Annotation{V}, ::Type{T}, i::Int, nm::Symbol) where {V,T} = Tables.getcolumn(getfield(ann, :_row), T, i, nm)::fieldtype(_annotation_fields(V), i)

function Tables.schema(::AbstractVector{<:Annotation{V}}) where {V}
    F = _annotation_fields(V)
    return Tables.Schema(fieldnames(F), fieldtypes(F))
end

is_valid_annotations_schema(::Nothing) = true
is_valid_annotations_schema(::Tables.Schema) = false
is_valid_annotations_schema(::Tables.Schema{fieldnames(_annotation_fields(Any)),<:Tuple{fieldtypes(_annotation_fields(Any))...}}) = true

struct Annotations{V,C} <: Tables.AbstractColumns
    _columns::C
    function Annotations(_columns::C) where {C}
        schema = Tables.schema(_columns)
        is_valid_annotations_schema(schema) || throw(ArgumentError("_table does not have appropriate Annotations schema: $schema"))
        V = schema === nothing ? Any : schema.types[end]
        return new{V,C}(_columns)
    end
end

Annotations{V}() where {V} = Annotations(Tables.columntable(_annotation_fields(V)[]))

Tables.istable(annotations::Annotations) = Tables.istable(getfield(annotations, :_columns))
Tables.schema(annotations::Annotations) = Tables.schema(getfield(annotations, :_columns))
Tables.materializer(annotations::Annotations) = Tables.materializer(getfield(annotations, :_columns))
Tables.rowaccess(annotations::Annotations) = Tables.rowaccess(getfield(annotations, :_columns))
Tables.rows(annotations::Annotations{V}) where {V} = (Annotation{V}(row) for row in Tables.rows(getfield(annotations, :_columns)))
Tables.columnaccess(annotations::Annotations) = Tables.columnaccess(getfield(annotations, :_columns))
Tables.columns(annotations::Annotations) = Tables.columns(getfield(annotations, :_columns))
Tables.columnnames(annotations::Annotations) = Tables.columnnames(getfield(annotations, :_columns))
Tables.getcolumn(annotations::Annotations, i::Int) = Tables.getcolumn(getfield(annotations, :_columns), i)
Tables.getcolumn(annotations::Annotations, nm::Symbol) = Tables.getcolumn(getfield(annotations, :_columns), nm)
Tables.getcolumn(annotations::Annotations, ::Type{T}, i::Int, nm::Symbol) where {T} = Tables.getcolumn(getfield(annotations, :_columns), T, i, nm)

#####
##### by_recording
#####

function by_recording(signals::Signals, annotations::Annotations{V}) where {V}
    recordings = Dict{UUID,NamedTuple{(:signals, :annotations),Tuple{Dict{String,Signal},Dict{UUID,Annotation{V}}}}}()
    for signal in Tables.rows(signals)
        recording = get!(() -> (signals = Dict{String,Signal}(), annotations = Dict{UUID,Annotation{V}}()),
                         recordings, signal.recording_uuid)
        recording.signals[signal.type] = signal
    end
    for annotation in Tables.rows(annotations)
        recording = get(recordings, annotation.recording_uuid, nothing)
        recording === nothing && continue
        recording.annotations[annotation.uuid] = annotation
    end
    return recordings
end

function by_recording(annotations::Annotations{V}, signals::Signals) where {V}
    recordings = Dict{UUID,NamedTuple{(:annotations, :signals),Tuple{Dict{UUID,Annotation{V}},Dict{String,Signal}}}}()
    for annotation in Tables.rows(annotations)
        recording = get!(() -> (annotations = Dict{UUID,Annotation{V}}(), signals = Dict{String,Signal}()),
                         recordings, annotation.recording_uuid)
        recording.annotations[annotation.uuid] = annotation
    end
    for signal in Tables.rows(signals)
        recording = get(recordings, signal.recording_uuid, nothing)
        recording === nothing && continue
        recording.signals[signal.type] = signal
    end
    return recordings
end

function by_recording(signals::Signals)
    recordings = Dict{UUID,Dict{String,Signal}}()
    for signal in Tables.rows(signals)
        recording = get!(() -> Dict{String,Signal}(), recordings, signal.recording_uuid)
        recording[signal.type] = signal
    end
    return recordings
end

function by_recording(annotations::Annotations{V}) where {V}
    recordings = Dict{UUID,Dict{UUID,Annotation{V}}}()
    for annotation in Tables.rows(annotations)
        recording = get!(() -> Dict{UUID,Annotation{V}}(), recordings, annotation.recording_uuid)
        recording[annotation.uuid] = annotation
    end
    return recordings
end
