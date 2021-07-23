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

convert_number_to_lpcm_sample_type(x::LPCM_SAMPLE_TYPE_UNION) = x
convert_number_to_lpcm_sample_type(x) = Float64(x)

#####
##### `SamplesInfo`
#####

"""
TODO
"""
const SamplesInfo = @row("onda.samples-info@1",
                         kind::AbstractString,
                         channels::AbstractVector{<:AbstractString},
                         sample_unit::AbstractString,
                         sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_resolution_in_unit),
                         sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_offset_in_unit),
                         sample_type::Type{<:LPCM_SAMPLE_TYPE_UNION} = julia_type_from_onda_sample_type(sample_type),
                         sample_rate::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_rate))

const SamplesInfoNamedTuple{K,C,U,R,O,T,S} = NamedTuple{(:kind, :channels, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate),
                                                        Tuple{K,C,U,R,O,T,S}}

const SamplesInfoArrowType{R,O,S} = SamplesInfoNamedTuple{String,Vector{String},String,R,O,String,S}

const SAMPLES_INFO_ARROW_NAME = Symbol("JuliaLang.SamplesInfo")

Arrow.ArrowTypes.arrowname(::Type{<:SamplesInfo}) = SAMPLES_INFO_ARROW_NAME

function Arrow.ArrowTypes.ArrowType(::Type{<:Legolas.Row{Legolas.Schema{Symbol("onda.samples-info"),1},
                                                         SamplesInfoNamedTuple{K,C,U,R,O,T,S}}}) where {K,C,U,R,O,T,S}
    return SamplesInfoArrowType{R,O,S}
end

function Arrow.ArrowTypes.toarrow(info::SamplesInfo)
    return (kind=convert(String, info.kind),
            channels=convert(Vector{String}, info.channels),
            sample_unit=convert(String, info.sample_unit),
            sample_resolution_in_unit=info.sample_resolution_in_unit,
            sample_offset_in_unit=info.sample_offset_in_unit,
            sample_type=onda_sample_type_from_julia_type(info.sample_type),
            sample_rate=info.sample_rate)
end

function Arrow.ArrowTypes.JuliaType(::Val{SAMPLES_INFO_ARROW_NAME}, ::Type{SamplesInfoArrowType{R,O,S}}) where {R,O,S}
    return Legolas.Row{Legolas.Schema{Symbol("onda.samples-info"),1},SamplesInfoArrowType{R,O,S}}
end

function Arrow.ArrowTypes.fromarrow(::Type{<:SamplesInfo}, kind, channels,
                                    sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                                    sample_type, sample_rate)
    return SamplesInfo(; kind, channels,
                       sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate)
end

#####
##### `Signal`
#####

"""
TODO
"""
const Signal = @row("onda.signal@1" > "onda.samples-info@1",
                    recording::UUID = UUID(recording),
                    file_format::String = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format,
                    span::TimeSpan = TimeSpan(span),
                    kind::String = _validate_signal_kind(kind),
                    channels::Vector{String} = _validate_signal_channels(channels),
                    sample_unit::String = _validate_signal_sample_unit(sample_unit),
                    sample_type::String = onda_sample_type_from_julia_type(sample_type))

function _validate_signal_kind(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal kind (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

function _validate_signal_sample_unit(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal sample unit (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

function _validate_signal_channels(x)
    for c in x
        is_lower_snake_case_alphanumeric(c, ('-', '.')) || throw(ArgumentError("invalid channel name (must be lowercase/snakecase/alphanumeric): $c"))
    end
    return x
end

extract_samples_info(signal) = SamplesInfo(; signal.kind, signal.channels, signal.sample_unit,
                                           signal.sample_resolution_in_unit, signal.sample_offset_in_unit,
                                           signal.sample_type, signal.sample_rate)

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
    sizeof_samples(x, duration::Period)

Returns the expected size (in bytes) of an encoded `Samples` object corresponding to `x` and `duration`:

    sample_count(x, duration) * channel_count(x) * sizeof(x.sample_type)

"""
sizeof_samples(x, duration::Period) = sample_count(x, duration) * channel_count(x) * sizeof(x.sample_type)