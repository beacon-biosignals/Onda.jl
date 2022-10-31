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

julia_type_from_onda_sample_type(T::Type{<:LPCM_SAMPLE_TYPE_UNION}) = T

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

onda_sample_type_from_julia_type(t::AbstractString) = onda_sample_type_from_julia_type(julia_type_from_onda_sample_type(t))

#####
##### validation utilities
#####

function _validate_signal_sensor_label(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal sensor label (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

function _validate_signal_sensor_type(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal sensor type (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

function _validate_signal_sample_unit(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal sample unit (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

function _validate_signal_channels(x)
    allunique(x) || throw(ArgumentError("invalid signal channels (duplicate channel names are disallowed): $x"))
    foreach(_validate_signal_channel, x)
    return x
end

function _validate_signal_channel(x)
    is_lower_snake_case_alphanumeric(x, ('-', '.', '+', '/', '(', ')')) || throw(ArgumentError("invalid channel name (must be lowercase/snakecase/alphanumeric): $x"))
    has_balanced_parens(x) || throw(ArgumentError("invalid channel name (parentheses must be balanced): $x"))
    return x
end

#####
##### `onda.samples-info`
#####

@schema "onda.samples-info" SamplesInfo

@version SamplesInfoV2 begin
    sensor_type::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::String = onda_sample_type_from_julia_type(sample_type)
    sample_rate::Float64
end

"""
    TODO
"""
SamplesInfoV2

#####
##### `onda.signal`
#####

@schema "onda.signal" Signal

@version SignalV2 > SamplesInfoV2 begin
    recording::UUID = UUID(recording)
    file_path::(<:Any)
    file_format::String = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format
    span::TimeSpan = TimeSpan(span)
    sensor_label::String = _validate_signal_sensor_label(sensor_label)
    sensor_type::String = _validate_signal_sensor_type(sensor_type)
    channels::Vector{String} = _validate_signal_channels(channels)
    sample_unit::String = _validate_signal_sample_unit(sample_unit)
end

Legolas.accepted_field_type(::SignalV2SchemaVersion, ::Type{TimeSpan}) = Union{NamedTupleTimeSpan,TimeSpan}

"""
    TODO
"""
SignalV2

"""
    validate_signals(signals)

Perform both table-level and row-level validation checks on the content of `signals`,
a presumed `onda.signal` table. Returns `signals`.

This function will throw an error in any of the following cases:

- `Legolas.validate(Tables.schema(signals), SignalV2SchemaVersion())` throws an error
- `SignalV2(r)` errors for any `r` in `Tables.rows(signals)`
- `signals` contains rows with duplicate `file_path`s
"""
validate_signals(signals) = _fully_validate_legolas_table(:validate_signals, signals, SignalV2, SignalV2SchemaVersion(), :file_path)

#####
##### duck-typed utilities
#####

"""
    channel(x, name)

Return `i` where `x.channels[i] == name`.
"""
channel(x, name) = findfirst(isequal(name), x.channels)

"""
    channel(x, i::Integer)

Return `x.channels[i]`.
"""
channel(x, i::Integer) = x.channels[i]

"""
    channel_count(x)

Return `length(x.channels)`.
"""
channel_count(x) = length(x.channels)

"""
    sample_count(x, duration::Period)

Return the number of multichannel samples that fit within `duration` given `x.sample_rate`.
"""
sample_count(x, duration::Period) = TimeSpans.index_from_time(x.sample_rate, duration) - 1

"""
    sample_type(x)

Return `x.sample_type` as an `Onda.LPCM_SAMPLE_TYPE_UNION` subtype. If `x.sample_type` is an Onda-specified `sample_type` string (e.g. `"int16"`), it will be converted to the corresponding Julia type. If `x.sample_type <: Onda.LPCM_SAMPLE_TYPE_UNION`, this function simply returns `x.sample_type` as-is.
"""
sample_type(x) = julia_type_from_onda_sample_type(x.sample_type)

"""
    sizeof_samples(x, duration::Period)

Returns the expected size (in bytes) of an encoded `Samples` object corresponding to `x` and `duration`:

    sample_count(x, duration) * channel_count(x) * sizeof(x.sample_type)

"""
sizeof_samples(x, duration::Period) = sample_count(x, duration) * channel_count(x) * sizeof(sample_type(x))
