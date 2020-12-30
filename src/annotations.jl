#####
##### Annotation <: Tables.AbstractRow
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

#####
##### Annotations <: Tables.AbstractColumns
#####

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
Tables.columns(annotations::Annotations) = annotations
Tables.columnnames(annotations::Annotations) = Tables.columnnames(getfield(annotations, :_columns))
Tables.getcolumn(annotations::Annotations, i::Int) = Tables.getcolumn(getfield(annotations, :_columns), i)
Tables.getcolumn(annotations::Annotations, nm::Symbol) = Tables.getcolumn(getfield(annotations, :_columns), nm)
Tables.getcolumn(annotations::Annotations, ::Type{T}, i::Int, nm::Symbol) where {T} = Tables.getcolumn(getfield(annotations, :_columns), T, i, nm)

Base.show(io::IO, annotations::Annotations) = pretty_table(io, annotations)

#####
##### read
#####

read_annotations(io_or_path; materialize::Bool=false) = Annotations(read_onda_table(io_or_path; materialize))
