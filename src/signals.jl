

#=
#####
##### SignalsRow <: Tables.AbstractRow
#####

struct SignalsRow{R} <: Tables.AbstractRow
    _row::R
end

const SIGNAL_FIELDS = NamedTuple{(:recording_uuid, :file_path, :file_format, :kind, :channels, :start_nanosecond, :stop_nanosecond, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate),
                                  Tuple{UUID,Any,String,String,Vector{String},Nanosecond,Nanosecond,String,Float64,Float64,String,Float64}}

function SignalsRow(; recording_uuid::UUID,
                    file_path,
                    file_format,
                    kind,
                    channels,
                    start_nanosecond,
                    stop_nanosecond,
                    sample_unit,
                    sample_resolution_in_unit,
                    sample_offset_in_unit,
                    sample_type,
                    sample_rate)
    return SignalsRow{SIGNAL_FIELDS}((; recording_uuid, file_path,
                                  file_format=String(file_format),
                                  kind=String(kind),
                                  channels=convert(Vector{String}, channels),
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

TimeSpans.istimespan(::Signal) = true
TimeSpans.start(signal::Signal) = signal.start_nanosecond
TimeSpans.stop(signal::Signal) = signal.stop_nanosecond

#####
##### Signals <: Tables.AbstractColumns
#####

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
Tables.columns(signals::Signals) = signals
Tables.columnnames(signals::Signals) = Tables.columnnames(getfield(signals, :_columns))
Tables.getcolumn(signals::Signals, i::Int) = Tables.getcolumn(getfield(signals, :_columns), i)
Tables.getcolumn(signals::Signals, nm::Symbol) = Tables.getcolumn(getfield(signals, :_columns), nm)
Tables.getcolumn(signals::Signals, ::Type{T}, i::Int, nm::Symbol) where {T} = Tables.getcolumn(getfield(signals, :_columns), T, i, nm)

Base.show(io::IO, signals::Signals) = pretty_table(io, signals)

read_signals(io_or_path; materialize::Bool=false) = Signals(read_onda_table(io_or_path; materialize))
=#