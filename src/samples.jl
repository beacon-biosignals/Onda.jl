#####
##### Samples
#####

"""
    VALIDATE_SAMPLES_DEFAULT[]

Defaults to `true`.

When set to `true`, `Samples` objects will be validated upon construction for compliance
with the Onda specification.

Users may interactively set this reference to `false` in order to disable this extra layer
validation, which can be useful when working with malformed Onda datasets.

See also: [`Onda.validate_samples`](@ref)
"""
const VALIDATE_SAMPLES_DEFAULT = Ref{Bool}(true)

"""
    Samples(data::AbstractMatrix, info::SamplesInfoV2, encoded::Bool;
            validate::Bool=Onda.VALIDATE_SAMPLES_DEFAULT[])

Return a `Samples` instance with the following fields:

- `data::AbstractMatrix`: A matrix of sample data. The `i` th row of the matrix
  corresponds to the `i`th channel in `info.channels`, while the `j`th
  column corresponds to the `j`th multichannel sample.

- `info::SamplesInfoV2`: The [`SamplesInfoV2`](@ref)-compliant value that describes the `Samples` instance.

- `encoded::Bool`: If `true`, the values in `data` are LPCM-encoded as prescribed
  by the `Samples` instance's `info`. If `false`, the values in `data` have
  been decoded into the `info`'s canonical units.

If `validate` is `true`, [`Onda.validate_samples`](@ref) is called on the constructed `Samples`
instance before it is returned.

Note that `getindex` and `view` are defined on `Samples` to accept normal integer
indices, but also accept channel names or a regex to match channel names for row indices,
and `TimeSpan` values for column indices; see `Onda/examples/tour.jl` for a comprehensive
set of indexing examples.

Note also that "slices" copied from `s::Samples` via `getindex(s, ...)` may alias `s.info` in
order to avoid excessive overhead. This means one should generally avoid directly mutating `s.info`,
especially `s.info.channels`.

See also: [`load`](@ref), [`store`](@ref), [`encode`](@ref), [`encode!`](@ref), [`decode`](@ref), [`decode!`](@ref)
"""
struct Samples{D<:AbstractMatrix}
    data::D
    info::SamplesInfoV2
    encoded::Bool
    function Samples(data, info::SamplesInfoV2, encoded::Bool;
                     validate::Bool=VALIDATE_SAMPLES_DEFAULT[])
        validate && validate_samples(data, info, encoded)
        return new{typeof(data)}(data, info, encoded)
    end
end

"""
    ==(a::Samples, b::Samples)

Returns `a.encoded == b.encoded && a.info == b.info && a.data == b.data`.
"""
Base.:(==)(a::Samples, b::Samples) = a.encoded == b.encoded && a.info == b.info && a.data == b.data

"""
    isequal(a::Samples, b::Samples)

Checks if each field of `a` and `b` are `isequal` to each other; specifically, this function returns `isequal(a.encoded, b.encoded) && isequal(a.info, b.info) && isequal(a.data, b.data)`.
"""
function Base.isequal(a::Samples, b::Samples)
    return isequal(a.encoded, b.encoded) && isequal(a.info, b.info) && isequal(a.data, b.data)
end

# Define in a compatible way as `isequal` so that two samples being `isequal` to each other
# ensures they have the same hash.
function Base.hash(a::Samples, h::UInt)
    return hash(Samples, hash(a.encoded, hash(a.info, hash(a.data, h))))
end

"""
    copy(s::Samples)

Return `Samples(copy(s.data), deepcopy(s.info), s.encoded)`
"""
Base.copy(s::Samples) = Samples(copy(s.data), copy(s.info), s.encoded)

"""
    validate_samples(data::AbstractMatrix, info, encoded)

Returns `nothing`, checking that the given `data` is valid w.r.t. the
underlying [`SamplesInfoV2`](@ref)-compliant `info` and the Onda specification's
canonical LPCM representation. If a violation is found, an `ArgumentError` is
thrown.

Properties that are validated by this function include:

- the number of rows of `data` must match the number of channels in `info`
- if `encoded` is `true`, `eltype(data)` must match `sample_type(info)`
"""
function validate_samples(data, info, encoded)
    n_channels = channel_count(info)
    n_rows = size(data, 1)
    if n_channels != n_rows
        throw(ArgumentError("number of channels in info ($n_channels) " *
                            "does not match number of rows in data matrix " *
                            "($n_rows)"))
    end
    if encoded && !(eltype(data) === sample_type(info))
        throw(ArgumentError("encoded `data` matrix eltype does not match `sample_type(info)`"))
    end
    return nothing
end

TimeSpans.istimespan(::Samples) = true
TimeSpans.start(::Samples) = Nanosecond(0)
TimeSpans.stop(samples::Samples) = TimeSpans.time_from_index(samples.info.sample_rate, size(samples.data, 2) + 1)

"""
    channel(samples::Samples, name)

Return `channel(samples.info, name)`.

This function is useful for indexing rows of `samples.data` by channel names.
"""
channel(samples::Samples, name) = channel(samples.info, name)

"""
    channel(samples::Samples, i::Integer)

Return `channel(samples.info, i)`.
"""
channel(samples::Samples, i::Integer) = channel(samples.info, i)

"""
    channel_count(samples::Samples)

Return `channel_count(samples.info)`.
"""
channel_count(samples::Samples) = channel_count(samples.info)

"""
    sample_count(samples::Samples)

Return the number of multichannel samples in `samples` (i.e. `size(samples.data, 2)`)
"""
sample_count(samples::Samples) = size(samples.data, 2)

#####
##### indexing
#####

for f in (:getindex, :view, :maybeview)
    @eval begin
        @inline function Base.$f(samples::Samples, rows, columns)
            rows = row_arguments(samples, rows)
            columns = column_arguments(samples, columns)
            info = rows isa Colon ? samples.info : SamplesInfoV2(rowmerge(samples.info; channels=samples.info.channels[rows]))
            return Samples(Base.$f(samples.data, rows, columns), info, samples.encoded; validate=false)
        end
    end
end

_rangify(i) = i
_rangify(i::Integer) = i:i

_indices_fallback(::Any, ::Samples, i::Union{Colon,AbstractRange,Integer}) = i
_indices_fallback(f, samples::Samples, x) = map(x -> f(samples, x), x)

row_arguments(samples::Samples, x) = _rangify(_row_arguments(samples, x))

_row_arguments(samples::Samples, x) = _indices_fallback(_row_arguments, samples, x)
function _row_arguments(samples::Samples, name::AbstractString)
    idx = channel(samples, name)
    idx === nothing && throw(ArgumentError("channel \"$(name)\" not found"))
    return idx
end
_row_arguments(samples::Samples, name::Regex) = findall(c -> match(name, c) !== nothing, samples.info.channels)

column_arguments(samples::Samples, x) = _rangify(_column_arguments(samples, x))

function _column_arguments(samples::Samples, x)
    TimeSpans.istimespan(x) && return TimeSpans.index_from_time(samples.info.sample_rate, TimeSpan(x))
    return _indices_fallback(_column_arguments, samples, x)
end

#####
##### encoding utilities
#####

function encode_sample(::Type{S}, resolution_in_unit, offset_in_unit, sample_in_unit,
                       noise=zero(sample_in_unit)) where {S<:LPCM_SAMPLE_TYPE_UNION}
    sample_in_unit += noise
    isnan(sample_in_unit) && S <: Integer && return typemax(S)
    from_unit = clamp((sample_in_unit - offset_in_unit) / resolution_in_unit, typemin(S), typemax(S))
    return S <: Integer ? round(S, from_unit) : from_unit
end

function dither_noise!(rng::AbstractRNG, storage, step)
    rand!(rng, storage)
    broadcast!(_dither_noise, storage, storage, step + step, step)
    return storage
end

dither_noise!(storage, step) = dither_noise!(Random.GLOBAL_RNG, storage, step)

function _dither_noise(x, range, step)
    rs = range * x
    if rs < step
        return sqrt(rs * step) - step
    else
        return step - sqrt(range * (1 - x) * step)
    end
end

#####
##### `encode`/`encode!`
#####

"""
    encode(sample_type::DataType, sample_resolution_in_unit, sample_offset_in_unit,
           sample_data, dither_storage=nothing)

Return a copy of `sample_data` quantized according to `sample_type`, `sample_resolution_in_unit`,
and `sample_offset_in_unit`. `sample_type` must be a concrete subtype of `Onda.LPCM_SAMPLE_TYPE_UNION`.
Quantization of an individual sample `s` is performed via:

    round(S, (s - sample_offset_in_unit) / sample_resolution_in_unit)

with additional special casing to clip values exceeding the encoding's dynamic range.

If `dither_storage isa Nothing`, no dithering is applied before quantization.

If `dither_storage isa Missing`, dither storage is allocated automatically and
triangular dithering is applied to the info prior to quantization.

Otherwise, `dither_storage` must be a container of similar shape and type to
`sample_data`. This container is then used to store the random noise needed for the
triangular dithering process, which is applied to the info prior to quantization.

If:

    sample_type === eltype(sample_data) &&
    sample_resolution_in_unit == 1 &&
    sample_offset_in_unit == 0

then this function will simply return `sample_data` directly without copying/dithering.
"""
function encode(::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
                sample_data, dither_storage=nothing) where {S<:LPCM_SAMPLE_TYPE_UNION}
    if (S === eltype(sample_data) &&
        sample_resolution_in_unit == 1 &&
        sample_offset_in_unit == 0)
        return sample_data
    end
    return encode!(similar(sample_data, S), S,
                   sample_resolution_in_unit, sample_offset_in_unit,
                   sample_data, dither_storage)
end

"""
    encode!(result_storage, sample_type::DataType, sample_resolution_in_unit,
            sample_offset_in_unit, sample_data, dither_storage=nothing)
    encode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,
            sample_data, dither_storage=nothing)

Similar to `encode(sample_type, sample_resolution_in_unit, sample_offset_in_unit, sample_data, dither_storage)`,
but write encoded values to `result_storage` rather than allocating new storage.

`sample_type` defaults to `eltype(result_storage)` if it is not provided.

If:

    sample_type === eltype(sample_data) &&
    sample_resolution_in_unit == 1 &&
    sample_offset_in_unit == 0

then this function will simply copy `sample_data` directly into `result_storage` without dithering.
"""
function encode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,
                 sample_data, dither_storage=nothing)
    return encode!(result_storage, eltype(result_storage), sample_resolution_in_unit,
                   sample_offset_in_unit, sample_data, dither_storage)
end

function encode!(result_storage, ::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
                 sample_data, dither_storage=nothing) where {S<:LPCM_SAMPLE_TYPE_UNION}
    if (S === eltype(sample_data) &&
        sample_resolution_in_unit == 1 &&
        sample_offset_in_unit == 0)
        copyto!(result_storage, sample_data)
    else
        if dither_storage isa Nothing
            broadcast!(encode_sample, result_storage, S,
                       sample_resolution_in_unit,
                       sample_offset_in_unit, sample_data)
        else
            if dither_storage isa Missing
                dither_storage = similar(sample_data)
            elseif size(dither_storage) != size(sample_data)
                throw(DimensionMismatch("dithering storage container does not match shape of sample_data"))
            end
            dither_noise!(dither_storage, sample_resolution_in_unit)
            broadcast!(encode_sample, result_storage, S,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_data, dither_storage)
        end
    end
    return result_storage
end

"""
    encode(samples::Samples, dither_storage=nothing)

If `samples.encoded` is `false`, return a `Samples` instance that wraps:

    encode(sample_type(samples.info),
           samples.info.sample_resolution_in_unit,
           samples.info.sample_offset_in_unit,
           samples.data, dither_storage)

If `samples.encoded` is `true`, this function is the identity.
"""
function encode(samples::Samples, dither_storage=nothing)
    samples.encoded && return samples
    return Samples(encode(sample_type(samples.info),
                          samples.info.sample_resolution_in_unit,
                          samples.info.sample_offset_in_unit,
                          samples.data, dither_storage),
                   samples.info, true; validate=false)
end

"""
    encode!(result_storage, samples::Samples, dither_storage=nothing)

If `samples.encoded` is `false`, return a `Samples` instance that wraps:

    encode!(result_storage,
            sample_type(samples.info),
            samples.info.sample_resolution_in_unit,
            samples.info.sample_offset_in_unit,
            samples.data, dither_storage)`.

If `samples.encoded` is `true`, return a `Samples` instance that wraps
`copyto!(result_storage, samples.data)`.
"""
function encode!(result_storage, samples::Samples, dither_storage=nothing)
    if samples.encoded
        copyto!(result_storage, samples.data)
    else
        encode!(result_storage, sample_type(samples.info),
                samples.info.sample_resolution_in_unit,
                samples.info.sample_offset_in_unit,
                samples.data, dither_storage)
    end
    return Samples(result_storage, samples.info, true; validate=false)
end

#####
##### `decode`/`decode!`
#####

"""
    decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)

Return `sample_resolution_in_unit .* sample_data .+ sample_offset_in_unit`.

If:

    sample_data isa AbstractArray &&
    sample_resolution_in_unit == 1 &&
    sample_offset_in_unit == 0

then this function is the identity and will return `sample_data` directly without copying.
"""
function decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)
    if sample_data isa AbstractArray
        isone(sample_resolution_in_unit) && iszero(sample_offset_in_unit) && return sample_data
    end
    return sample_resolution_in_unit .* sample_data .+ sample_offset_in_unit
end

"""
    decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, sample_data)

Similar to `decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)`, but
write decoded values to `result_storage` rather than allocating new storage.
"""
function decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, sample_data)
    f = x -> sample_resolution_in_unit * x + sample_offset_in_unit
    return broadcast!(f, result_storage, sample_data)
end

"""
    decode(samples::Samples, ::Type{T}=Float64)

If `samples.encoded` is `true`, return a `Samples` instance that wraps

    decode(convert(T, samples.info.sample_resolution_in_unit),
           convert(T, samples.info.sample_offset_in_unit),
           samples.data)

If `samples.encoded` is `false`, this function is the identity.
"""
function decode(samples::Samples, ::Type{T}=Float64) where {T}
    samples.encoded || return samples
    return Samples(decode(convert(T, samples.info.sample_resolution_in_unit),
                          convert(T, samples.info.sample_offset_in_unit),
                          samples.data),
                   samples.info, false; validate=false)
end

"""
    decode!(result_storage, samples::Samples)

If `samples.encoded` is `true`, return a `Samples` instance that wraps

    decode!(result_storage, samples.info.sample_resolution_in_unit, samples.info.sample_offset_in_unit, samples.data)

If `samples.encoded` is `false`, return a `Samples` instance that wraps `copyto!(result_storage, samples.data)`.
"""
function decode!(result_storage, samples::Samples)
    if samples.encoded
        decode!(result_storage, samples.info.sample_resolution_in_unit,
                samples.info.sample_offset_in_unit, samples.data)
    else
        copyto!(result_storage, samples.data)
    end
    return Samples(result_storage, samples.info, false; validate=false)
end

#####
##### load/store
#####

"""
    load(signal[, span_relative_to_loaded_samples]; encoded::Bool=false)
    load(file_path, file_format::Union{AbstractString,AbstractLPCMFormat},
         info[, span_relative_to_loaded_samples]; encoded::Bool=false)

Return the `Samples` object described by `signal`/`file_path`/`file_format`/`info`.

If `span_relative_to_loaded_samples` is present, return `load(...)[:, span_relative_to_loaded_samples]`,
but attempt to avoid reading unreturned intermediate sample data. Note that the effectiveness of this
optimized method versus the naive approach depends on the types of `file_path` (i.e. if there is a fast
method defined for `Onda.read_byte_range(::typeof(file_path), ...)`) and `file_format` (i.e. does the
corresponding format support random or chunked access).

If `encoded` is `true`, do not decode the `Samples` object before returning it.
"""
function load(signal, span_relative_to_loaded_samples...; encoded::Bool=false)
    return @compat load(signal.file_path, signal.file_format, SamplesInfoV2(signal),
                        span_relative_to_loaded_samples...; encoded)
end

function load(file_path, file_format::AbstractString, info,
              span_relative_to_loaded_samples...; encoded::Bool=false)
    return @compat load(file_path, format(file_format, info), info,
                        span_relative_to_loaded_samples...; encoded)
end

function load(file_path, file_format::AbstractLPCMFormat, info; encoded::Bool=false)
    samples = Samples(read_lpcm(file_path, file_format), info, true)
    return encoded ? samples : decode(samples)
end

function load(file_path, file_format::AbstractLPCMFormat, info,
              span_relative_to_loaded_samples; encoded::Bool=false)
    sample_range = TimeSpans.index_from_time(info.sample_rate, span_relative_to_loaded_samples)
    sample_offset_from_info, sample_count_from_info = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(file_path, file_format, sample_offset_from_info, sample_count_from_info)
    samples = Samples(sample_data, info, true)
    if sample_count(samples) < sample_count_from_info
        throw(ArgumentError("""
                            `duration(load(..., span_relative_to_loaded_samples))` is unexpectedly less than
                            `duration(span_relative_to_loaded_samples)`; this might indicate that `span` is
                            not properly within the bounds of the loaded `Samples` instance.

                            Try `load(...)[:, span_relative_to_loaded_samples]` to load the full `Samples` instance
                            before indexing, which might induce a more informative `BoundsError`.
                            """))
    end
    return encoded ? samples : decode(samples)
end

"""
    Onda.mmap(signal)

Return `Onda.mmap(signal.file_path, SamplesInfoV2(signal))`, throwing an `ArgumentError` if `signal.file_format != "lpcm"`.
"""
function mmap(signal)
    signal.file_format == "lpcm" || throw(ArgumentError("unsupported file_format for mmap: $(signal.file_format)"))
    return mmap(signal.file_path, SamplesInfoV2(signal))
end

"""
    Onda.mmap(mmappable, info)

Return `Samples(data, info, true)` where `data` is created via `Mmap.mmap(mmappable, ...)`.

`mmappable` is assumed to reference memory that is formatted according to the Onda Format's canonical
interleaved LPCM representation in accordance with `sample_type(info)` and `channel_count(info)`. No
explicit checks are performed to ensure that this is true.
"""
function mmap(mmappable, info)
    data = reshape(Mmap.mmap(mmappable, Vector{sample_type(info)}), (channel_count(info), :))
    return Samples(data, info, true)
end

"""
    store(file_path, file_format::Union{AbstractString,AbstractLPCMFormat}, samples::Samples)

Serialize the given `samples` to `file_format` and write the output to `file_path`.
"""
function store(file_path, file_format, samples::Samples)
    fmt = file_format isa AbstractLPCMFormat ? file_format : format(file_format, samples.info)
    return write_lpcm(file_path, fmt, encode(samples).data)
end

"""
    store(file_path, file_format::Union{AbstractString,AbstractLPCMFormat},
          samples::Samples, recording::UUID, start::Period,
          sensor_label::AbstractString = samples.info.sensor_type)

Serialize the given `samples` to `file_format` and write the output to `file_path`, returning
a `SignalV2` instance constructed from the provided arguments.
"""
function store(file_path, file_format, samples::Samples, recording, start,
               sensor_label=samples.info.sensor_type)
    store(file_path, file_format, samples)
    span = TimeSpan(start, Nanosecond(start) + TimeSpans.duration(samples))
    row = rowmerge(samples.info; recording, sensor_label, file_path, file_format, span)
    return SignalV2(row)
end

#####
##### pretty printing
#####

function Base.show(io::IO, samples::Samples)
    if get(io, :compact, false)
        print(io, "Samples(", summary(samples.data), ')')
    else
        duration_in_seconds = size(samples.data, 2) / samples.info.sample_rate
        duration_in_nanoseconds = round(Int, duration_in_seconds * 1_000_000_000)
        println(io, "Samples (", TimeSpans.format_duration(duration_in_nanoseconds), "):")
        println(io, "  info.sensor_type: ", repr(samples.info.sensor_type))
        println(io, "  info.channels: ", string('[', join(map(repr, samples.info.channels), ", "), ']'))
        println(io, "  info.sample_unit: ", repr(samples.info.sample_unit))
        println(io, "  info.sample_resolution_in_unit: ", samples.info.sample_resolution_in_unit)
        println(io, "  info.sample_offset_in_unit: ", samples.info.sample_offset_in_unit)
        println(io, "  sample_type(info): ", sample_type(samples.info))
        println(io, "  info.sample_rate: ", samples.info.sample_rate, " Hz")
        println(io, "  encoded: ", samples.encoded)
        println(io, "  data:")
        show(io, "text/plain", samples.data)
    end
end

#####
##### Arrow conversion
#####

const SamplesArrowType{T} = NamedTuple{(:data, :info, :encoded),Tuple{Vector{T},Arrow.ArrowTypes.ArrowType(SamplesInfoV2),Bool}}

const SAMPLES_ARROW_NAME = Symbol("JuliaLang.Samples")

Arrow.ArrowTypes.arrowname(::Type{<:Samples}) = SAMPLES_ARROW_NAME

Arrow.ArrowTypes.ArrowType(::Type{<:Samples{D}}) where {D} = SamplesArrowType{eltype(D)}

function Arrow.ArrowTypes.toarrow(samples::Samples)
    return (data=vec(samples.data),
            info=Arrow.ArrowTypes.toarrow(samples.info),
            encoded=samples.encoded)
end

function Arrow.ArrowTypes.JuliaType(::Val{SAMPLES_ARROW_NAME}, ::Type{<:SamplesArrowType{T}}) where {T}
    return Samples{Matrix{T}}
end

function Arrow.ArrowTypes.fromarrow(::Type{<:Samples}, arrow_data, arrow_info, arrow_encoded)
    info = Arrow.ArrowTypes.fromarrow(SamplesInfoV2, arrow_info)
    data = reshape(arrow_data, (channel_count(info), :))
    return Samples(data, info, arrow_encoded)
end

# Legolas v0.5.17 removed the `fromarrow` methods for Legolas rows, preferring the new `fromarrowstruct`
# introduced in Arrow v2.7. We don't want to assume Arrow v2.7 is loaded here, so we will add a method
# so that `fromarrow` continues to work for `SamplesInfoV2`. Additionally, this method is agnostic
# to serialization order of fields (which is the benefit `fromarrowstruct` is designed to bring), so
# we retain correctness. Lastly, as this method's signature is different from the one Legolas pre-v0.5.17
# generates, we avoid method overwriting errors/warnings.
Arrow.ArrowTypes.fromarrow(::Type{SamplesInfoV2}, x::NamedTuple) = SamplesInfoV2(x)
