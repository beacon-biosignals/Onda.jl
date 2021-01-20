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

#####
##### `*.signals` table
#####

"""
TODO
"""
struct Signal{P}
    recording_uuid::UUID
    file_path::P
    file_format::String
    start::Nanosecond
    stop::Nanosecond
    kind::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::String
    sample_rate::Float64
end

function Signal(recording_uuid, file_path::P, file_format, start, stop,
                kind, channels, sample_unit, sample_resolution_in_unit,
                sample_offset_in_unit, sample_type, sample_rate) where {P}
    recording_uuid = recording_uuid isa UUID ? recording_uuid : UUID(recording_uuid)
    sample_type = String(sample_type isa DataType ? onda_sample_type_from_julia_type(sample_type) : sample_type)
    file_format = String(file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format)
    timespan = TimeSpan(start, stop)
    return Signal{P}(recording_uuid, file_path, file_format,
                     TimeSpans.start(timespan), TimeSpans.stop(timespan),
                     String(kind), convert(Vector{String}, channels), String(sample_unit),
                     convert(Float64, sample_resolution_in_unit),
                     convert(Float64, sample_offset_in_unit),
                     sample_type, convert(Float64, sample_rate))
end

function Signal(; recording_uuid, file_path, file_format, start, stop,
                kind, channels, sample_unit, sample_resolution_in_unit,
                sample_offset_in_unit, sample_type, sample_rate)
    return Signal(recording_uuid, file_path, file_format, start, stop,
                  kind, channels, sample_unit, sample_resolution_in_unit,
                  sample_offset_in_unit, sample_type, sample_rate)
end

function Signal(info::SamplesInfo; recording_uuid, file_path, file_format, start, stop)
    return Signal(; recording_uuid, file_path, file_format, start, stop,
                  info.kind, info.channels, info.sample_unit, info.sample_resolution_in_unit,
                  info.sample_offset_in_unit, info.sample_type, info.sample_rate)
end

Signal(x) = Signal(x.recording_uuid, x.file_path, x.file_format, x.start, x.stop,
                   x.kind, x.channels, x.sample_unit, x.sample_resolution_in_unit,
                   x.sample_offset_in_unit, x.sample_type, x.sample_rate)

Tables.schema(::AbstractVector{S}) where {S<:Signal} = Tables.Schema(fieldnames(S), fieldtypes(S))

TimeSpans.istimespan(::Signal) = true
TimeSpans.start(signal::Signal) = signal.start
TimeSpans.stop(signal::Signal) = signal.stop

const SIGNALS_COLUMN_NAMES = (:recording_uuid, :file_path, :file_format, :start, :stop,
                              :kind, :channels, :sample_unit, :sample_resolution_in_unit,
                              :sample_offset_in_unit, :sample_type, :sample_rate)

const SIGNALS_READABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Any,AbstractString,Period,Period,
                                            AbstractString,AbstractVector{<:AbstractString},AbstractString,LPCM_SAMPLE_TYPE_UNION,
                                            LPCM_SAMPLE_TYPE_UNION,AbstractString,Real}

const SIGNALS_WRITABLE_COLUMN_TYPES = Tuple{Union{UUID,UInt128},Any,String,Nanosecond,Nanosecond,
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