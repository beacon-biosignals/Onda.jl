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
    const SamplesInfo = @row("onda.samples-info@1",
                             kind::String,
                             channels::Vector{String},
                             sample_unit::String,
                             sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION,
                             sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION,
                             sample_type::String = Onda.onda_sample_type_from_julia_type(sample_type),
                             sample_rate::LPCM_SAMPLE_TYPE_UNION)

A type alias for [`Legolas.Row{typeof(Legolas.Schema("onda.samples-info@1"))}`](https://beacon-biosignals.github.io/Legolas.jl/stable/#Legolas.@row)
representing the bundle of `onda.signal` fields that are intrinsic to a signal's sample data,
leaving out extrinsic file or recording information. This is useful when the latter information
is irrelevant or does not yet exist (e.g. if sample data is being constructed/manipulated in-memory
without yet having been serialized).
"""
const SamplesInfo = @row("onda.samples-info@1",
                         kind::AbstractString = convert(String, kind),
                         channels::AbstractVector{<:AbstractString} = convert(Vector{String}, channels),
                         sample_unit::AbstractString = convert(String, sample_unit),
                         sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_resolution_in_unit),
                         sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_offset_in_unit),
                         sample_type::AbstractString = onda_sample_type_from_julia_type(sample_type),
                         sample_rate::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_rate))

#####
##### `Signal`
#####

# Note that the real field type restrictions here are more lax than the documented
# ones for improved compatibility with data produced by older Onda.jl versions and/or
# non-Julia producers.
"""
    const Signal = @row("onda.signal@1" > "onda.samples-info@1",
                        recording::UUID,
                        file_path::Any,
                        file_format::String = (file_format isa AbstractLPCMFormat ?
                                               Onda.file_format_string(file_format) :
                                               file_format),
                        span::TimeSpan,
                        kind::String,
                        channels::Vector{String},
                        sample_unit::String)

A type alias for [`Legolas.Row{typeof(Legolas.Schema("onda.signal@1"))}`](https://beacon-biosignals.github.io/Legolas.jl/stable/#Legolas.@row)
representing an `onda.signal` as described by the [Onda Format Specification](https://github.com/beacon-biosignals/Onda.jl#the-onda-format-specification).

This type primarily exists to aid in the validated row construction, and is not intended to be used
as a type constraint in function or struct definitions. Instead, you should generally duck-type any
"signal-like" arguments/fields so that other generic row types will compose with your code.
"""
const Signal = @row("onda.signal@1" > "onda.samples-info@1",
                    recording::Union{UInt128,UUID} = UUID(recording),
                    file_path::Any,
                    file_format::AbstractString = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format,
                    span::Union{NamedTupleTimeSpan,TimeSpan} = TimeSpan(span),
                    kind::AbstractString = _validate_signal_kind(kind),
                    channels::AbstractVector{<:AbstractString} = _validate_signal_channels(channels),
                    sample_unit::AbstractString = _validate_signal_sample_unit(sample_unit))

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

"""
    write_signals(io_or_path, table; kwargs...)

Invoke/return `Legolas.write(path_or_io, signals, Schema("onda.signal@1"); kwargs...)`.
"""
write_signals(path_or_io, signals; kwargs...) = Legolas.write(path_or_io, signals, Legolas.Schema("onda.signal@1"); kwargs...)

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

Return `julia_type_from_onda_sample_type(x.sample_type)`.
"""
sample_type(x) = julia_type_from_onda_sample_type(x.sample_type)

"""
    sizeof_samples(x, duration::Period)

Returns the expected size (in bytes) of an encoded `Samples` object corresponding to `x` and `duration`:

    sample_count(x, duration) * channel_count(x) * sizeof(x.sample_type)

"""
sizeof_samples(x, duration::Period) = sample_count(x, duration) * channel_count(x) * sizeof(sample_type(x))

