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

validate_signal_schema(::Nothing) = @warn "`schema == nothing`; skipping schema validation"

function validate_signal_schema(schema::Tables.Schema)
    length(schema.names) >= 11 || throw(ArgumentError("invalid `Signal` fields: need at least 11 fields, input has $(length(schema.names))"))
    for (i, (name, T)) in enumerate((:recording => Union{UInt128,UUID},
                                     :file_path => Any,
                                     :file_format => AbstractString,
                                     :span => Union{NamedTupleTimeSpan,TimeSpan},
                                     :kind => AbstractString,
                                     :channels => AbstractVector{<:AbstractString},
                                     :sample_unit => AbstractString,
                                     :sample_resolution_in_unit => LPCM_SAMPLE_TYPE_UNION,
                                     :sample_offset_in_unit => LPCM_SAMPLE_TYPE_UNION,
                                     :sample_type => AbstractString,
                                     :sample_rate => LPCM_SAMPLE_TYPE_UNION))
        schema.names[i] === name || throw(ArgumentError("invalid `Signal` fields: field $i must be named `:$(name)`, got $(schema.names[i])"))
        schema.types[i] <: T || throw(ArgumentError("invalid `Signal` fields: invalid `:$(name)` field type: $(schema.types[i])"))
    end
    return nothing
end

#####
##### Signal
#####

"""
    Signal(signals_table_row)
    Signal(recording, file_path, file_format, span, kind, channels, sample_unit,
           sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
           custom...)
    Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
           sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
           custom...)
    Signal(info::SamplesInfo; recording, file_path, file_format, span, custom...)

Return a `Signal` instance that represents a row of an `*.onda.signals.arrow` table

The names, types, and order of the columns of a `Signal` instance are guaranteed to
result in a `*.onda.signals.arrow`-compliant row when written out via `write_signals`.
The exception is the `file_path` column, whose type is unchecked in order to allow
callers to utilize custom path types.

This type primarily exists to aid in the validated construction of such rows/tables,
and is not intended to be used as a type constraint in function or struct definitions.
Instead, you should generally duck-type any "signal-like" arguments/fields so that
other generic row types will compose with your code.

This type supports Tables.jl's `AbstractRow` interface (but does not subtype `AbstractRow`).
"""
struct Signal{R}
    _row::R
    function Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
                    sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                    custom...)
        recording::UUID = recording isa UUID ? recording : UUID(recording)
        file_format::String = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format
        span::TimeSpan = TimeSpan(span)
        kind::String = kind
        channels::Vector{String} = channels
        sample_unit::String = sample_unit
        sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION = sample_resolution_in_unit isa LPCM_SAMPLE_TYPE_UNION ? sample_resolution_in_unit : Float64(sample_resolution_in_unit)
        sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION = sample_offset_in_unit isa LPCM_SAMPLE_TYPE_UNION ? sample_offset_in_unit : Float64(sample_offset_in_unit)
        sample_type::String = sample_type isa DataType ? onda_sample_type_from_julia_type(sample_type) : sample_type
        sample_rate::LPCM_SAMPLE_TYPE_UNION = sample_rate isa LPCM_SAMPLE_TYPE_UNION ? sample_rate : Float64(sample_rate)
        _row = (; recording, file_path, file_format, span, kind, channels, sample_unit,
                sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                custom...)
        return new{typeof(_row)}(_row)
    end
end

Signal(row) = Signal(NamedTuple(Tables.Row(row)))
Signal(row::NamedTuple) = Signal(; row...)
Signal(row::Signal) = row

function Signal(recording, file_path, file_format, span, kind, channels, sample_unit,
                sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
                custom...)
    return Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
                  sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                  custom...)
end

Base.propertynames(x::Signal) = propertynames(getfield(x, :_row))
Base.getproperty(x::Signal, name::Symbol) = getproperty(getfield(x, :_row), name)

ConstructionBase.setproperties(x::Signal, patch::NamedTuple) = Signal(setproperties(getfield(x, :_row), patch))

Tables.getcolumn(x::Signal, i::Int) = Tables.getcolumn(getfield(x, :_row), i)
Tables.getcolumn(x::Signal, nm::Symbol) = Tables.getcolumn(getfield(x, :_row), nm)
Tables.columnnames(x::Signal) = Tables.columnnames(getfield(x, :_row))

#####
##### read/write
#####

"""
    read_signals(io_or_path; validate_schema::Bool=false)

Return the `*.onda.signals.arrow`-compliant table read from `io_or_path`.

If `validate_schema` is `true`, the table's schema will be validated to ensure it is
a `*.onda.signals.arrow`-compliant table. An `ArgumentError` will be thrown if
any schema violation is detected.
"""
function read_signals(io_or_path; materialize::Union{Missing,Bool}=missing, validate_schema::Bool=false)
    table = read_onda_table(io_or_path)
    validate_schema && validate_signal_schema(Tables.schema(table))
    if materialize isa Bool
        if materialize
            @warn "`read_signals(x; materialize=true)` is deprecated; use `Onda.materialize(read_signals(x))` instead"
            return Onda.materialize(table)
        else
            @warn "`read_signals(x; materialize=false)` is deprecated; use `read_signals(x)` instead"
        end
    end
    return table
end

"""
    write_signals(io_or_path, table; kwargs...)

Write `table` to `io_or_path`, first validating that `table` is a compliant
`*.onda.signals.arrow` table. An `ArgumentError` will be thrown if any
schema violation is detected.

`kwargs` is forwarded to an internal invocation of `Arrow.write(...; file=true, kwargs...)`.
"""
function write_signals(io_or_path, table; kwargs...)
    validate_schema = schema -> try
        validate_signal_schema(schema)
    catch
        @warn "Invalid schema in input `table`. Try calling `Onda.Signal.(Tables.rows(table))` to see if it is convertible to the required schema."
        rethrow()
    end
    return write_onda_table(io_or_path, table; validate_schema, kwargs...)
end

#####
##### `SamplesInfo`
#####

"""
    SamplesInfo(; kind, channels, sample_unit,
                sample_resolution_in_unit, sample_offset_in_unit,
                sample_type, sample_rate,
                validate::Bool=Onda.validate_on_construction())
    SamplesInfo(kind, channels, sample_unit,
                sample_resolution_in_unit, sample_offset_in_unit,
                sample_type, sample_rate;
                validate::Bool=Onda.validate_on_construction())
    SamplesInfo(signals_table_row; validate::Bool=Onda.validate_on_construction())

Return a `SamplesInfo` instance whose fields are a subset of a `*.onda.signals.arrow` row:

- `kind`
- `channels`
- `sample_unit`
- `sample_resolution_in_unit`
- `sample_offset_in_unit`
- `sample_type`
- `sample_rate`

The `SamplesInfo` struct bundles together the fields of a `*.onda.signals.arrow` row that are
intrinsic to a signal's sample data, leaving out extrinsic file or recording information.
This is useful when the latter information is irrelevant or does not yet exist (e.g. if
sample data is being constructed/manipulated in-memory without yet having been serialized).

Bundling these fields together under a common type facilitates dispatch for various Onda API
functions. Additionally:

- If `validate` is `true`, then `Onda.validate` is called on new instances upon construction.

- The provided `sample_type` may be either an Onda-compliant string or a `DataType`. If it is
  a string, it will be converted to its corresponding `DataType`.
"""
struct SamplesInfo{K<:AbstractString,
                   C<:AbstractVector{<:AbstractString},
                   U<:AbstractString,
                   R<:LPCM_SAMPLE_TYPE_UNION,
                   O<:LPCM_SAMPLE_TYPE_UNION,
                   S<:LPCM_SAMPLE_TYPE_UNION,
                   SR<:LPCM_SAMPLE_TYPE_UNION}
    kind::K
    channels::C
    sample_unit::U
    sample_resolution_in_unit::R
    sample_offset_in_unit::O
    sample_type::Type{S}
    sample_rate::SR
    function SamplesInfo(kind::K, channels::C, sample_unit::U,
                         sample_resolution_in_unit::R,
                         sample_offset_in_unit::O,
                         sample_type, sample_rate::SR;
                         validate::Bool=Onda.validate_on_construction()) where {K,C,U,R,O,SR}
        S = sample_type isa Type ? sample_type : julia_type_from_onda_sample_type(sample_type)
        info = new{K,C,U,R,O,S,SR}(kind, channels, sample_unit, sample_resolution_in_unit,
                                   sample_offset_in_unit, S, sample_rate)
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

Returns `nothing`, checking that the given `info.kind`, `info.channels` and `info.sample_unit`
are valid w.r.t. the Onda specification. If a violation is found, an `ArgumentError` is thrown.
"""
function validate(info::SamplesInfo)
    is_lower_snake_case_alphanumeric(info.kind) || throw(ArgumentError("invalid signal kind (must be lowercase/snakecase/alphanumeric): $(info.kind)"))
    is_lower_snake_case_alphanumeric(info.sample_unit) || throw(ArgumentError("invalid sample unit (must be lowercase/snakecase/alphanumeric): $(info.sample_unit)"))
    for c in info.channels
        is_lower_snake_case_alphanumeric(c, ('-', '.')) || throw(ArgumentError("invalid channel name (must be lowercase/snakecase/alphanumeric): $c"))
    end
    return nothing
end

Base.:(==)(a::SamplesInfo, b::SamplesInfo) = all(name -> getfield(a, name) == getfield(b, name), fieldnames(SamplesInfo))

function Signal(info::SamplesInfo; recording, file_path, file_format, span, custom...)
    return Signal(; recording, file_path, file_format, span,
                  info.kind, info.channels, info.sample_unit, info.sample_resolution_in_unit,
                  info.sample_offset_in_unit, info.sample_type, info.sample_rate, custom...)
end

#####
##### Arrow conversion
#####

const SamplesInfoArrowType{R,O,SR} = NamedTuple{(:kind, :channels, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate),
                                                Tuple{String,Vector{String},String,R,O,String,SR}}

const SAMPLES_INFO_ARROW_NAME = Symbol("JuliaLang.SamplesInfo")

Arrow.ArrowTypes.arrowname(::Type{<:SamplesInfo}) = SAMPLES_INFO_ARROW_NAME

Arrow.ArrowTypes.ArrowType(::Type{<:SamplesInfo{<:Any,<:Any,<:Any,R,O,<:Any,SR}}) where {R,O,SR} = SamplesInfoArrowType{R,O,SR}

function Arrow.ArrowTypes.toarrow(info::SamplesInfo)
    return (kind=convert(String, info.kind),
            channels=convert(Vector{String}, info.channels),
            sample_unit=convert(String, info.sample_unit),
            sample_resolution_in_unit=info.sample_resolution_in_unit,
            sample_offset_in_unit=info.sample_offset_in_unit,
            sample_type=onda_sample_type_from_julia_type(info.sample_type),
            sample_rate=info.sample_rate)
end

function Arrow.ArrowTypes.JuliaType(::Val{SAMPLES_INFO_ARROW_NAME}, ::Type{SamplesInfoArrowType{R,O,SR}}) where {R,O,SR}
    return SamplesInfo{String,Vector{String},String,R,O,<:LPCM_SAMPLE_TYPE_UNION,SR}
end

Arrow.ArrowTypes.fromarrow(::Type{<:SamplesInfo}, fields...) = SamplesInfo(fields...; validate=false)

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