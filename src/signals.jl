#####
##### `LPCM_SAMPLE_TYPE_UNION`
#####

const LPCM_SAMPLE_TYPE_UNION = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,Float32,Float64}

function julia_type_from_onda_sample_type(t::AbstractString)
    t == "int8" && return Int8
    t == "int16" && return Int16
    t == "int32" && return Int32
    t == "int64" && return Int64
    t == "uint8" && return UInt8
    t == "uint16" && return UInt16
    t == "uint32" && return UInt32
    t == "uint64" && return UInt64
    t == "float32" && return Float32
    t == "float64" && return Float64
    throw(ArgumentError("sample type $t is not supported by Onda"))
end

function onda_sample_type_from_julia_type(T::Type)
    T === Int8 && return "int8"
    T === Int16 && return "int16"
    T === Int32 && return "int32"
    T === Int64 && return "int64"
    T === UInt8 && return "uint8"
    T === UInt16 && return "uint16"
    T === UInt32 && return "uint32"
    T === UInt64 && return "uint64"
    T === Float32 && return "float32"
    T === Float64 && return "float64"
    throw(ArgumentError("sample type $T is not supported by Onda"))
end

#####
##### validation
#####

# manually unrolling the accesses here seems to enable better constant propagation
@inline function _validate_signal_fields(names, types)
    names[1] === :recording || throw(ArgumentError("invalid `Signal` fields: field 1 must be named `:recording`, got $(names[1])"))
    names[2] === :file_path || throw(ArgumentError("invalid `Signal` fields: field 2 must be named `:file_path`, got $(names[2])"))
    names[3] === :file_format || throw(ArgumentError("invalid `Signal` fields: field 3 must be named `:file_format`, got $(names[3])"))
    names[4] === :span || throw(ArgumentError("invalid `Signal` fields: field 4 must be named `:span`, got $(names[4])"))
    names[5] === :kind || throw(ArgumentError("invalid `Signal` fields: field 5 must be named `:kind`, got $(names[5])"))
    names[6] === :channels || throw(ArgumentError("invalid `Signal` fields: field 6 must be named `:channels`, got $(names[6])"))
    names[7] === :sample_unit || throw(ArgumentError("invalid `Signal` fields: field 7 must be named `:sample_unit`, got $(names[7])"))
    names[8] === :sample_resolution_in_unit || throw(ArgumentError("invalid `Signal` fields: field 8 must be named `:sample_resolution_in_unit`, got $(names[8])"))
    names[9] === :sample_offset_in_unit || throw(ArgumentError("invalid `Signal` fields: field 9 must be named `:sample_offset_in_unit`, got $(names[9])"))
    names[10] === :sample_type || throw(ArgumentError("invalid `Signal` fields: field 10 must be named `:sample_type`, got $(names[10])"))
    names[11] === :sample_rate || throw(ArgumentError("invalid `Signal` fields: field 11 must be named `:sample_rate`, got $(names[11])"))
    types[1] <: Union{UInt128,UUID} || throw(ArgumentError("invalid `Signal` fields: invalid `:recording` field type: $(types[1])"))
    # types[2] <: Any || throw(ArgumentError("invalid `Signal` fields: invalid `:file_path` field type: $(types[2])"))
    types[3] <: String || throw(ArgumentError("invalid `Signal` fields: invalid `:file_format` field type: $(types[3])"))
    types[4] <: Union{NamedTupleTimeSpan,TimeSpan} || throw(ArgumentError("invalid `Signal` fields: invalid `:span` field type: $(types[4])"))
    types[5] <: String || throw(ArgumentError("invalid `Signal` fields: invalid `:kind` field type: $(types[5])"))
    types[6] <: Vector{String} || throw(ArgumentError("invalid `Signal` fields: invalid `:channels` field type: $(types[6])"))
    types[7] <: String || throw(ArgumentError("invalid `Signal` fields: invalid `:sample_unit` field type: $(types[7])"))
    types[8] <: LPCM_SAMPLE_TYPE_UNION || throw(ArgumentError("invalid `Signal` fields: invalid `:sample_resolution_in_unit` field type: $(types[8])"))
    types[9] <: LPCM_SAMPLE_TYPE_UNION || throw(ArgumentError("invalid `Signal` fields: invalid `:sample_offset_in_unit` field type: $(types[9])"))
    types[10] <: String || throw(ArgumentError("invalid `Signal` fields: invalid `:sample_type` field type: $(types[10])"))
    types[11] <: LPCM_SAMPLE_TYPE_UNION || throw(ArgumentError("invalid `Signal` fields: invalid `:sample_rate` field type: $(types[11])"))
   return nothing
end

@inline _validate_signal_field_count(n) = n >= 11 || throw(ArgumentError("invalid `Signal` fields: need at least 11 fields, input has $n"))

function validate_signal_row(row)
    names = Tables.columnnames(row)
    _validate_signal_field_count(length(names))
    types = (typeof(Tables.getcolumn(row, 1)),
             typeof(Tables.getcolumn(row, 2)),
             typeof(Tables.getcolumn(row, 3)),
             typeof(Tables.getcolumn(row, 4)),
             typeof(Tables.getcolumn(row, 5)),
             typeof(Tables.getcolumn(row, 6)),
             typeof(Tables.getcolumn(row, 7)),
             typeof(Tables.getcolumn(row, 8)),
             typeof(Tables.getcolumn(row, 9)),
             typeof(Tables.getcolumn(row, 10)),
             typeof(Tables.getcolumn(row, 11)))
    _validate_signal_fields(names, types)
    return nothing
end

validate_signal_schema(::Nothing) = @warn "`schema == nothing`; skipping schema validation"

function validate_signal_schema(schema::Tables.Schema)
    _validate_signal_field_count(length(schema.names))
    _validate_signal_fields(schema.names, schema.types)
    return nothing
end

#####
##### Signal
#####

struct Signal{R}
    _row::R
    function Signal(_row::R) where {R}
        validate_signal_row(_row)
        return new{R}(_row)
    end
    function Signal(recording, file_path, file_format, span,
                    kind, channels, sample_unit, sample_resolution_in_unit,
                    sample_offset_in_unit, sample_type, sample_rate; custom...)
        recording = recording isa UUID ? recording : UUID(recording)
        sample_type = String(sample_type isa DataType ? onda_sample_type_from_julia_type(sample_type) : sample_type)
        file_format = String(file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format)
        _row = (; recording, file_path, file_format, TimeSpan(span),
                String(kind), convert(Vector{String}, channels), String(sample_unit),
                convert(Float64, sample_resolution_in_unit),
                convert(Float64, sample_offset_in_unit),
                sample_type, convert(Float64, sample_rate), custom...)
        return new{typeof(_row)}(_row)
    end
end

function Signal(; recording, file_path, file_format, span,
                kind, channels, sample_unit, sample_resolution_in_unit,
                sample_offset_in_unit, sample_type, sample_rate, custom...)
    return Signal(recording, file_path, file_format, span,
                  kind, channels, sample_unit, sample_resolution_in_unit,
                  sample_offset_in_unit, sample_type, sample_rate, custom...)
end

Base.propertynames(x::Signal) = propertynames(getfield(x, :_row))
Base.getproperty(x::Signal, name::Symbol) = getproperty(getfield(x, :_row), name)

Tables.getcolumn(x::Signal, i::Int) = Tables.getcolumn(getfield(x, :_row), i)
Tables.getcolumn(x::Signal, nm::Symbol) = Tables.getcolumn(getfield(x, :_row), nm)
Tables.columnnames(x::Signal) = Tables.columnnames(getfield(x, :_row))

TimeSpans.istimespan(::Signal) = true
TimeSpans.start(x::Signal) = TimeSpans.start(x.span)
TimeSpans.stop(x::Signal) = TimeSpans.stop(x.span)

#####
##### read/write
#####

function read_signals(io_or_path; materialize::Bool=false, validate_schema::Bool=true)
    table = read_onda_table(io_or_path; materialize)
    validate_schema && validate_signal_schema(Tables.schema(table))
    return table
end

function write_signals(io_or_path, table; kwargs...)
    columns = Tables.columns(table)
    schema = Tables.schema(columns)
    try
        validate_signal_schema(schema)
    catch
        @warn "Invalid schema in input `table`. Try calling `Onda.Signal.(Tables.rows(table))` to see if it is convertible to the required schema."
        rethrow()
    end
    return write_onda_table(io_or_path, table; kwargs...)
end


#=
#####
##### `SamplesInfo`
#####

"""
TODO
"""
struct SamplesInfo{K<:AbstractString,
                   C<:AbstractVector{<:AbstractString},
                   U<:AbstractString,
                   T<:LPCM_SAMPLE_TYPE_UNION,
                   S<:LPCM_SAMPLE_TYPE_UNION}
    kind::K
    channels::C
    sample_unit::U
    sample_resolution_in_unit::T
    sample_offset_in_unit::T
    sample_type::Type{S}
    sample_rate::Float64
    function SamplesInfo(kind::K, channels::C, sample_unit::U,
                         sample_resolution_in_unit::SRU,
                         sample_offset_in_unit::SOU,
                         sample_type, sample_rate;
                         validate::Bool=Onda.validate_on_construction()) where {K,C,U,SRU,SOU}
        T = typeintersect(promote_type(SRU, SOU), LPCM_SAMPLE_TYPE_UNION)
        S = sample_type isa Type ? sample_type : julia_type_from_onda_sample_type(sample_type)
        info = new{K,C,U,T,S}(kind, channels, sample_unit,
                                convert(T, sample_resolution_in_unit),
                                convert(T, sample_offset_in_unit),
                                S, convert(Float64, sample_rate))
        validate && Onda.validate(info)
        return info
    end
end

function SamplesInfo(; kind, channels, sample_unit,
                     sample_resolution_in_unit, sample_offset_in_unit,
                     sample_type, sample_rate,
                     validate::Bool=Onda.validate_on_construction())
    return SamplesInfo(kind, channels, sample_unit,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate; validate)
end

function SamplesInfo(row; validate::Bool=Onda.validate_on_construction())
    return SamplesInfo(row.kind, row.channels, row.sample_unit,
                       row.sample_resolution_in_unit, row.sample_offset_in_unit,
                       row.sample_type, row.sample_rate; validate)
end

"""
    validate(info::SamplesInfo)

Returns `nothing`, checking that the given `info.sample_unit` and `info.channels` are
valid w.r.t. the Onda specification. If a violation is found, an `ArgumentError` is thrown.
"""
function validate(info::SamplesInfo)
    is_lower_snake_case_alphanumeric(info.sample_unit) || throw(ArgumentError("invalid sample unit (must be lowercase/snakecase/alphanumeric): $(info.sample_unit)"))
    for c in info.channels
        is_lower_snake_case_alphanumeric(c, ('-', '.')) || throw(ArgumentError("invalid channel name (must be lowercase/snakecase/alphanumeric): $c"))
    end
    return nothing
end

Base.:(==)(a::SamplesInfo, b::SamplesInfo) = all(name -> getfield(a, name) == getfield(b, name), fieldnames(SamplesInfo))

"""
    channel(info::SamplesInfo, name)

Return `i` where `info.channels[i] == name`.
"""
channel(info::SamplesInfo, name) = findfirst(isequal(name), info.channels)

"""
    channel(info::SamplesInfo, i::Integer)

Return `info.channels[i]`.
"""
channel(info::SamplesInfo, i::Integer) = info.channels[i]

"""
    channel_count(info::SamplesInfo)

Return `length(info.channels)`.
"""
channel_count(info::SamplesInfo) = length(info.channels)

"""
    sample_count(info::SamplesInfo, duration::Period)

Return the number of multichannel samples that fit within `duration` given `info.sample_rate`.
"""
sample_count(info::SamplesInfo, duration::Period) = TimeSpans.index_from_time(info.sample_rate, duration) - 1

"""
    sizeof_samples(info::SamplesInfo, duration::Period)

Returns the expected size (in bytes) of an encoded `Samples` object corresponding to `info` and `duration`:

    sample_count(info, duration) * channel_count(info) * sizeof(info.sample_type)

"""
sizeof_samples(info::SamplesInfo, duration::Period) = sample_count(info, duration) * channel_count(info) * sizeof(info.sample_type)
=#


#=
#####
##### `*.signals` table
#####

"""
TODO
"""
struct Signal{P}
    recording::UUID
    file_path::P
    file_format::String
    span::TimeSpan
    kind::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::String
    sample_rate::Float64
end

function Signal(recording, file_path::P, file_format, span,
                kind, channels, sample_unit, sample_resolution_in_unit,
                sample_offset_in_unit, sample_type, sample_rate) where {P}
    recording = recording isa UUID ? recording : UUID(recording)
    sample_type = String(sample_type isa DataType ? onda_sample_type_from_julia_type(sample_type) : sample_type)
    file_format = String(file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format)
    return Signal{P}(recording, file_path, file_format, TimeSpan(span),
                     String(kind), convert(Vector{String}, channels), String(sample_unit),
                     convert(Float64, sample_resolution_in_unit),
                     convert(Float64, sample_offset_in_unit),
                     sample_type, convert(Float64, sample_rate))
end

function Signal(; recording, file_path, file_format, span,
                kind, channels, sample_unit, sample_resolution_in_unit,
                sample_offset_in_unit, sample_type, sample_rate)
    return Signal(recording, file_path, file_format, span,
                  kind, channels, sample_unit, sample_resolution_in_unit,
                  sample_offset_in_unit, sample_type, sample_rate)
end

function Signal(info::SamplesInfo; recording, file_path, file_format, span)
    return Signal(; recording, file_path, file_format, span,
                  info.kind, info.channels, info.sample_unit, info.sample_resolution_in_unit,
                  info.sample_offset_in_unit, info.sample_type, info.sample_rate)
end

Signal(x) = Signal(x.recording, x.file_path, x.file_format, x.span,
                   x.kind, x.channels, x.sample_unit, x.sample_resolution_in_unit,
                   x.sample_offset_in_unit, x.sample_type, x.sample_rate)

Tables.schema(::AbstractVector{S}) where {S<:Signal} = Tables.Schema(fieldnames(S), fieldtypes(S))

TimeSpans.istimespan(::Signal) = true
TimeSpans.start(signal::Signal) = TimeSpans.start(signal.span)
TimeSpans.stop(signal::Signal) = TimeSpans.stop(signal.span)

const SIGNALS_COLUMN_NAMES = (:recording, :file_path, :file_format, :span,
                              :kind, :channels, :sample_unit, :sample_resolution_in_unit,
                              :sample_offset_in_unit, :sample_type, :sample_rate)

const SIGNALS_READABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Any,AbstractString,Any,
                                            AbstractString,AbstractVector{<:AbstractString},AbstractString,LPCM_SAMPLE_TYPE_UNION,
                                            LPCM_SAMPLE_TYPE_UNION,AbstractString,Real}

const SIGNALS_WRITABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Any,String,TimeSpan,
                                            String,Vector{String},String,Float64,Float64,String,Float64}

is_readable_signals_schema(::Any) = false
is_readable_signals_schema(::Tables.Schema{SIGNALS_COLUMN_NAMES,<:SIGNALS_READABLE_COLUMN_TYPES}) = true

is_writable_signals_schema(::Any) = false
is_writable_signals_schema(::Tables.Schema{SIGNALS_COLUMN_NAMES,<:SIGNALS_WRITABLE_COLUMN_TYPES}) = true

"""
TODO
"""
function read_signals(io_or_path; materialize::Bool=false, error_on_invalid_schema::Bool=false)
    table = read_onda_table(io_or_path; materialize)
    invalid_schema_error_message = error_on_invalid_schema ? "schema must have names matching `Onda.SIGNALS_COLUMN_NAMES` and types matching `Onda.SIGNALS_READABLE_COLUMN_TYPES`" : nothing
    validate_schema(is_readable_signals_schema, Tables.schema(table); invalid_schema_error_message)
    return table
end

"""
TODO
"""
function write_signals(io_or_path, table; kwargs...)
    invalid_schema_error_message = """
                                   schema must have names matching `Onda.SIGNALS_COLUMN_NAMES` and types matching `Onda.SIGNALS_WRITABLE_COLUMN_TYPES`.
                                   Try calling `Onda.Signal.(Tables.rows(table))` on your `table` to see if it is convertible to the required schema.
                                   """
    validate_schema(is_writable_signals_schema, Tables.schema(table); invalid_schema_error_message)
    return write_onda_table(io_or_path, table; kwargs...)
end
=#