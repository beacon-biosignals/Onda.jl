#####
##### MsgPack conversions for Base types
#####

MsgPack.msgpack_type(::Type{Nanosecond}) = MsgPack.IntegerType()
MsgPack.from_msgpack(::Type{Nanosecond}, x::Integer) = Nanosecond(x)
MsgPack.to_msgpack(::MsgPack.IntegerType, x::Nanosecond) = x.value

MsgPack.msgpack_type(::Type{VersionNumber}) = MsgPack.StringType()
MsgPack.from_msgpack(::Type{VersionNumber}, x::String) = VersionNumber(x[2:end])
MsgPack.to_msgpack(::MsgPack.StringType, x::VersionNumber) = string('v', x)

MsgPack.msgpack_type(::Type{UUID}) = MsgPack.StringType()
MsgPack.from_msgpack(::Type{UUID}, x::String) = UUID(x)
MsgPack.to_msgpack(::MsgPack.StringType, x::UUID) = string(x)

MsgPack.msgpack_type(::Type{DataType}) = MsgPack.StringType()
MsgPack.from_msgpack(::Type{DataType}, x::String) = julia_type_from_onda_sample_type(x)
MsgPack.to_msgpack(::MsgPack.StringType, T::DataType) = onda_sample_type_from_julia_type(T)

#####
##### Julia DataType <--> Onda `sample_type` string
#####

function julia_type_from_onda_sample_type(t::AbstractString)
    t == "int8" && return Int8
    t == "int16" && return Int16
    t == "int32" && return Int32
    t == "int64" && return Int64
    t == "uint8" && return UInt8
    t == "uint16" && return UInt16
    t == "uint32" && return UInt32
    t == "uint64" && return UInt64
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
    throw(ArgumentError("sample type $T is not supported by Onda"))
end

#####
##### annotations
#####

"""
    Annotation <: AbstractTimeSpan

A type representing an individual Onda annotation object. Instances contain
the following fields, following the Onda specification for annotation objects:

- `value::String`
- `start_nanosecond::Nanosecond`
- `stop_nanosecond::Nanosecond`

Similarly to the [`TimeSpan`](@ref) constructor, this constructor will add a single
`Nanosecond` to `stop_nanosecond` if `start_nanosecond == stop_nanosecond`.
"""
struct Annotation <: AbstractTimeSpan
    value::String
    start_nanosecond::Nanosecond
    stop_nanosecond::Nanosecond
    function Annotation(value::AbstractString, start::Nanosecond, stop::Nanosecond)
        span = TimeSpan(start, stop)
        return new(value, first(span), last(span))
    end
end

MsgPack.msgpack_type(::Type{Annotation}) = MsgPack.StructType()

function Annotation(value, span::AbstractTimeSpan)
    return Annotation(value, first(span), last(span))
end

Base.first(annotation::Annotation) = annotation.start_nanosecond

Base.last(annotation::Annotation) = annotation.stop_nanosecond

#####
##### signals
#####

"""
    Signal

A type representing an individual Onda signal object. Instances contain
the following fields, following the Onda specification for signal objects:

- `channel_names::Vector{Symbol}`
- `start_nanosecond::Nanosecond`
- `stop_nanosecond::Nanosecond`
- `sample_unit::Symbol`
- `sample_resolution_in_unit::Float64`
- `sample_offset_in_unit::Float64`
- `sample_type::DataType`
- `sample_rate::Float64`
- `file_extension::Symbol`
- `file_options::Union{Nothing,Dict{Symbol,Any}}`

If [`validate_on_construction`](@ref) returns `true`, [`validate_signal`](@ref)
is called on all new `Signal` instances upon construction.

Similarly to the [`TimeSpan`](@ref) constructor, this constructor will add a single
`Nanosecond` to `stop_nanosecond` if `start_nanosecond == stop_nanosecond`.
"""
Base.@kwdef struct Signal
    channel_names::Vector{Symbol}
    start_nanosecond::Nanosecond
    stop_nanosecond::Nanosecond
    sample_unit::Symbol
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::DataType
    sample_rate::Float64
    file_extension::Symbol
    file_options::Union{Nothing,Dict{Symbol,Any}}
    function Signal(channel_names, start_nanosecond, stop_nanosecond,
                    sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                    sample_type, sample_rate, file_extension, file_options,
                    validate=true)
        stop_nanosecond += Nanosecond(start_nanosecond == stop_nanosecond)
        signal = new(channel_names, start_nanosecond, stop_nanosecond,
                     sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                     sample_type, sample_rate, file_extension, file_options)
        validate_on_construction() && validate && validate_signal(signal)
        return signal
    end
end

is_valid_sample_type(T::Type) = onda_sample_type_from_julia_type(T) isa AbstractString
is_valid_sample_unit(u) = is_lower_snake_case_alphanumeric(string(u))
is_valid_channel_name(c) = is_lower_snake_case_alphanumeric(string(c), ('-', '.'))

"""
    validate_signal(signal::Signal)

Returns `nothing`, checking that the given `signal` is valid w.r.t. the Onda
specification. If a violation is found, an `ArgumentError` is thrown.

Properties that are validated by this function include:

- `sample_type` is a valid Onda sample type
- `sample_unit` name is lowercase, snakecase, and alphanumeric
- `start_nanosecond`/`stop_nanosecond` form a valid time span
- channel names are lowercase, snakecase, and alphanumeric
"""
function validate_signal(signal::Signal)
    validate_timespan(signal.start_nanosecond, signal.stop_nanosecond)
    is_valid_sample_type(signal.sample_type) || throw(ArgumentError("invalid sample type: $(signal.sample_type)"))
    is_valid_sample_unit(signal.sample_unit) || throw(ArgumentError("invalid sample unit: $(signal.sample_unit)"))
    foreach(signal.channel_names) do c
        is_valid_channel_name(c) || throw(ArgumentError("invalid channel name: $c"))
    end
    return nothing
end

function Base.:(==)(a::Signal, b::Signal)
    return all(name -> getfield(a, name) == getfield(b, name), fieldnames(Signal))
end

MsgPack.msgpack_type(::Type{Signal}) = MsgPack.StructType()

function file_option(signal::Signal, name, default)
    signal.file_options isa Dict && return get(signal.file_options, name, default)
    return default
end

"""
    signal_from_template(signal::Signal;
                         channel_names=signal.channel_names,
                         start_nanosecond=signal.start_nanosecond,
                         stop_nanosecond=signal.stop_nanosecond,
                         sample_unit=signal.sample_unit,
                         sample_resolution_in_unit=signal.sample_resolution_in_unit,
                         sample_offset_in_unit=signal.sample_offset_in_unit,
                         sample_type=signal.sample_type,
                         sample_rate=signal.sample_rate,
                         file_extension=signal.file_extension,
                         file_options=signal.file_options)

Return a `Signal` where each field is mapped to the corresponding keyword argument.
"""
function signal_from_template(signal::Signal;
                              channel_names=signal.channel_names,
                              start_nanosecond=signal.start_nanosecond,
                              stop_nanosecond=signal.stop_nanosecond,
                              sample_unit=signal.sample_unit,
                              sample_resolution_in_unit=signal.sample_resolution_in_unit,
                              sample_offset_in_unit=signal.sample_offset_in_unit,
                              sample_type=signal.sample_type,
                              sample_rate=signal.sample_rate,
                              file_extension=signal.file_extension,
                              file_options=signal.file_options,
                              validate=true)
    return Signal(channel_names, start_nanosecond, stop_nanosecond,
                  sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                  sample_type, sample_rate, file_extension, file_options, validate)
end

"""
    channel(signal::Signal, name::Symbol)

Return `i` where `signal.channel_names[i] == name`.
"""
channel(signal::Signal, name::Symbol) = findfirst(isequal(name), signal.channel_names)

"""
    channel(signal::Signal, i::Integer)

Return `signal.channel_names[i]`.
"""
channel(signal::Signal, i::Integer) = signal.channel_names[i]

"""
    channel_count(signal::Signal)

Return `length(signal.channel_names)`.
"""
channel_count(signal::Signal) = length(signal.channel_names)

"""
    span(signal::Signal)

Return `TimeSpan(signal.start_nanosecond, signal.stop_nanosecond)`.
"""
span(signal::Signal) = TimeSpan(signal.start_nanosecond, signal.stop_nanosecond)

"""
    duration(signal::Signal)

Return `duration(span(signal))`.
"""
duration(signal::Signal) = duration(span(signal))

"""
    sample_count(signal::Signal)

Return the number of multichannel samples that fit within `duration(signal)`
given `signal.sample_rate`.
"""
sample_count(signal::Signal) = index_from_time(signal.sample_rate, duration(signal)) - 1

"""
    sizeof_samples(signal::Signal)

Returns the expected size (in bytes) of the encoded `Samples` object corresponding
to the entirety of `signal`:

    sample_count(signal) * channel_count(signal) * sizeof(signal.sample_type)
"""
sizeof_samples(signal::Signal) = sample_count(signal) * channel_count(signal) * sizeof(signal.sample_type)

#####
##### recordings
#####

"""
    Recording

A type representing an individual Onda recording object. Instances contain
the following fields, following the Onda specification for recording objects:

- `signals::Dict{Symbol,Signal}`
- `annotations::Set{Annotation}`
"""
struct Recording
    signals::Dict{Symbol,Signal}
    annotations::Set{Annotation}
end

function Base.:(==)(a::Recording, b::Recording)
    return all(name -> getfield(a, name) == getfield(b, name), fieldnames(Recording))
end

MsgPack.msgpack_type(::Type{Recording}) = MsgPack.StructType()

"""
    annotate!(recording::Recording, annotation::Annotation)

Returns `push!(recording.annotations, annotation)`.
"""
annotate!(recording::Recording, annotation::Annotation) = push!(recording.annotations, annotation)

"""
    duration(recording::Recording)

Returns `maximum(s -> s.stop_nanosecond, values(recording.signals))`; throws an
`ArgumentError` if `recording.signals` is empty.
"""
function duration(recording::Recording)
    isempty(recording.signals) && throw(ArgumentError("`duration(recording)` is not defined if `isempty(recording.signals)`"))
    return maximum(s -> s.stop_nanosecond, values(recording.signals))
end

"""
    set_span!(recording::Recording, name::Symbol, span::AbstractTimeSpan)

Replace `recording.signals[name]` with a copy that has the `start_nanosecond`
and `start_nanosecond` fields set to match the provided `span`. Returns the
newly constructed `Signal` instance.
"""
function set_span!(recording::Recording, name::Symbol, span::AbstractTimeSpan)
    signal = signal_from_template(recording.signals[name];
                                  start_nanosecond=first(span),
                                  stop_nanosecond=last(span))
    recording.signals[name] = signal
    return signal
end

"""
    set_span!(recording::Recording, span::TimeSpan)

Return `Dict(name => set_span!(recording, name, span) for name in keys(recording.signals))`
"""
function set_span!(recording::Recording, span::AbstractTimeSpan)
    return Dict(name => set_span!(recording, name, span) for name in keys(recording.signals))
end
