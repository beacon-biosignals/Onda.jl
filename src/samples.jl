"""
    Samples(data::AbstractMatrix, encoded::Bool, signal::Signal;
            validate::Bool=Onda.validate_on_construction())

    Samples(data::AbstractMatrix;
            encoded::Bool = false,
            kind::String,
            channels::Vector{String},
            sample_unit::String,
            sample_resolution_in_unit::Float64 = 1.0,
            sample_offset_in_unit::Float64 = 0.0,
            sample_type::Type{S} = eltype(data),
            sample_rate::Float64,
            validated::Bool=Onda.validate_on_construction())

Return a `Samples` instance with the following fields:

- `data::AbstractMatrix`: A matrix of sample data. The `i` th row of the matrix
   corresponds to the `i`th channel in `signal.channels`, while the `j`th
   column corresponds to the `j`th multichannel sample.

- `encoded::Bool`: If `true`, the values in `data` are LPCM-encoded as
   prescribed by the `Samples` instance's `signal`. If `false`, the values in
   `data` have been decoded into the `signal`'s canonical units.

- `kind::String`: The `kind` field of the `Signal` object that describes the `Samples` instance.

- `channels::Vector{String}`: The `channels` field of the `Signal` object that describes the `Samples` instance

- `sample_unit::String`: The `sample_unit` field of the `Signal` object that describes the `Samples` instance

- `sample_resolution_in_unit::Float64`: The `sample_resolution_in_unit` field of the `Signal` object that describes the `Samples` instance

- `sample_offset_in_unit::Float64`: The `sample_offset_in_unit` field of the `Signal` object that describes the `Samples` instance

- `sample_type::Type{S}`: The `sample_type` field of the `Signal` object that describes the `Samples` instance

- `sample_rate::Float64`: The `sample_rate` field of the `Signal` object that describes the `Samples` instance

- `validated::Bool`: If `true`, [`validate_samples`](@ref) was called on the `Samples` instance when it was constructed.

Note that `getindex` and `view` are defined on `Samples` to accept normal integer
indices, but also accept channel names for row indices and [`TimeSpan`](@ref)
values for column indices; see `Onda/examples/tour.jl` for a comprehensive
set of indexing examples.

See also: [`load`](@ref), [`store`](@ref), [`encode`](@ref), [`encode!`](@ref), [`decode`](@ref), [`decode!`](@ref)
"""
struct Samples{D<:AbstractMatrix,S<:LPCM_SAMPLE_TYPE_UNION}
    data::D
    encoded::Bool
    kind::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::Type{S}
    sample_rate::Float64
    validated::Bool
    function Samples(data::D, encoded::Bool, kind, channels, sample_unit,
                     sample_resolution_in_unit, sample_offset_in_unit,
                     sample_type::Type{S}, sample_rate,
                     validated::Bool=validate_on_construction()) where {D,S}
        samples = new{typeof(data),S}(signal, encoded, kind, channels, sample_unit,
                                      sample_resolution_in_unit, sample_offset_in_unit,
                                      sample_type, sample_rate, validated)
        validated && validate_samples(samples)
        return samples
    end
end

function Samples(data; encoded=false, kind, channels,
                 sample_unit,
                 sample_resolution_in_unit=1.0, sample_offset_in_unit=0.0,
                 sample_type=eltype(data), sample_rate,
                 validated=validate_on_construction())
    return Samples(data, encoded, kind, channels,
                   sample_unit, sample_resolution_in_unit, sample_offset_in_unit,
                   sample_type, sample_rate,
                   validated)
end

function Samples(data, encoded::Bool, signal::Signal; validated=validate_on_construction())
    return Samples(data, encoded, signal.kind, signal.channels,
                   signal.sample_unit, signal.sample_resolution_in_unit, signal.sample_offset_in_unit,
                   julia_type_from_onda_sample_type(signal.sample_type), signal.sample_rate,
                   validated)
end

function Base.:(==)(a::Samples, b::Samples)
    return a.encoded == b.encoded &&
           a.kind == b.kind &&
           a.channels == b.channels &&
           a.sample_unit == b.sample_unit &&
           a.sample_resolution_in_unit == b.sample_resolution_in_unit &&
           a.sample_offset_in_unit == b.sample_offset_in_unit &&
           a.sample_type == b.sample_type &&
           a.sample_rate == b.sample_rate &&
           a.data == b.data
end

"""
    validate_samples(samples::Samples)

Returns `nothing`, checking that the given `samples` are valid w.r.t. the
underlying `samples.signal` and the Onda specification's canonical LPCM
representation. If a violation is found, an `ArgumentError` is thrown.

Properties that are validated by this function include:

- encoded element type matches `samples.signal.sample_type`
- the number of rows of `samples.data` matches the number of channels in `samples.signal`
"""
function validate_samples(samples::Samples)
    n_channels = channel_count(samples)
    n_rows = size(samples.data, 1)
    if n_channels != n_rows
        throw(ArgumentError("number of channels in signal ($n_channels) " *
                            "does not match number of rows in data matrix " *
                            "($n_rows)"))
    end
    if samples.encoded && !(eltype(samples.data) === samples.sample_type)
        throw(ArgumentError("signal and encoded data matrix have mismatched element types"))
    end
    return nothing
end

TimeSpans.istimespan(::Samples) = true
TimeSpans.start(::Samples) = Nanosecond(0)
TimeSpans.stop(samples::Samples) = TimeSpans.time_from_index(samples.sample_rate, size(samples.data, 2) + 1)

"""
    sample_count(samples::Samples)

Return the number of multichannel samples in `samples` (i.e. `size(samples.data, 2)`)
"""
sample_count(samples::Samples) = size(samples.data, 2)

#####
##### indexing
#####

for f in (:getindex, :view)
    @eval begin
        @inline function Base.$f(samples::Samples, rows, columns)
            rows = row_arguments(samples, rows)
            columns = column_arguments(samples, columns)
            return setproperties(samples;
                                 data=$f(samples.data, rows, columns),
                                 channels=rows isa Colon ? samples.channels : samples.channels[rows],
                                 validated=false)
        end
    end
end

_rangify(i) = i
_rangify(i::Integer) = i:i

_indices_fallback(::Any, ::Samples, i::Union{Colon,AbstractRange,Integer}) = i
_indices_fallback(f, samples::Samples, x) = map(x -> f(samples, x), x)

row_arguments(samples::Samples, x) = _rangify(_row_arguments(samples, x))
_row_arguments(samples::Samples, x) = _indices_fallback(_row_arguments, samples, x)
_row_arguments(samples::Samples, name::AbstractString) = channel(samples, name)

column_arguments(samples::Samples, x) = _rangify(_column_arguments(samples, x))
function _column_arguments(samples::Samples, x)
    TimeSpans.istimespan(x) && return index_from_time(samples.sample_rate, TimeSpan(x))
    return _indices_fallback(_column_arguments, samples, x)
end

#####
##### load/store
#####

"""
    load(signal::Signal)

Return the `Samples` object described by `signal`.
"""
function load(signal::Signal; encoded::Bool=false)
    samples = Samples(read_lpcm(signal.file_path, format(signal)), true, signal)
    return encoded ? samples : decode(samples)
end

"""
    load(signal::Signal, timespan)

Return `load(signal)[:, timespan]`, but attempt to avoid reading unreturned intermediate
sample data. Note that the effectiveness of this method over the aforementioned primitive
expression depends on the types of both `signal.file_path` and `format(signal)`.
"""
function load(signal::Signal, timespan; encoded::Bool=false)
    sample_range = TimeSpans.index_from_time(signal.sample_rate, timespan)
    sample_offset, sample_count = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(signal.file_path, format(signal), sample_offset, sample_count)
    samples = Samples(sample_data, true, signal)
    return encoded ? samples : decode(samples)
end

"""
TODO
"""
function store(recording_uuid, file_path, file_format, samples::Samples; kwargs...)
    signal = Signal(; recording_uuid, file_path, file_format, samples.kind, samples.channels,
                    samples.sample_unit, samples.sample_resolution_in_unit, samples.sample_offset_in_unit,
                    sample_type=onda_sample_type_from_julia_type(samples.sample_type),
                    samples.sample_rate)
    write_lpcm(file_path, encode(samples).data, format(signal; kwargs...))
    return signal
end

####
#### encoding utilities
####

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
and `sample_offset_in_unit`. `sample_type` must be a concrete subtype of `Onda.VALID_SAMPLE_TYPE_UNION`.
Quantization of an individual sample `s` is performed via:

    round(S, (s - sample_offset_in_unit) / sample_resolution_in_unit)

with additional special casing to clip values exceeding the encoding's dynamic range.

If `dither_storage isa Nothing`, no dithering is applied before quantization.

If `dither_storage isa Missing`, dither storage is allocated automatically and
triangular dithering is applied to the signal prior to quantization.

Otherwise, `dither_storage` must be a container of similar shape and type to
`sample_data`. This container is then used to store the random noise needed for the
triangular dithering process, which is applied to the signal prior to quantization.

If:

```
sample_type === eltype(sample_data) &&
sample_resolution_in_unit == 1 &&
sample_offset_in_unit == 0
```

then this function will simply return `sample_data` directly without copying/dithering.
"""
function encode(::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
                sample_data, dither_storage=nothing) where {S}
    if (sample_type === eltype(sample_data) &&
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

```
sample_type === eltype(sample_data) &&
sample_resolution_in_unit == 1 &&
sample_offset_in_unit == 0
```

then this function will simply copy `sample_data` directly into `result_storage` without dithering.
"""
function encode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,
                 sample_data, dither_storage=nothing)
    return encode!(result_storage, eltype(result_storage), sample_resolution_in_unit,
                   sample_offset_in_unit, sample_data, dither_storage)
end

function encode!(result_storage, ::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
                 sample_data, dither_storage=nothing) where {S}
    if (sample_type === eltype(sample_data) &&
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

    encode(samples.signal.sample_type,
           samples.signal.sample_resolution_in_unit,
           samples.signal.sample_offset_in_unit,
           samples.data, dither_storage)

If `samples.encoded` is `true`, this function is the identity.
"""
function encode(samples::Samples, dither_storage=nothing)
    samples.encoded && return samples
    return setproperties(samples;
                         data=encode(samples.sample_type,
                                     samples.sample_resolution_in_unit,
                                     samples.sample_offset_in_unit,
                                     samples.data, dither_storage),
                         encoded=true,
                         validated=false)
end

"""
    encode!(result_storage, samples::Samples, dither_storage=nothing)

If `samples.encoded` is `false`, return a `Samples` instance that wraps:

    encode!(result_storage,
            samples.signal.sample_type,
            samples.signal.sample_resolution_in_unit,
            samples.signal.sample_offset_in_unit,
            samples.data, dither_storage)`.

If `samples.encoded` is `true`, return a `Samples` instance that wraps
`copyto!(result_storage, samples.data)`.
"""
function encode!(result_storage, samples::Samples, dither_storage=nothing)
    if samples.encoded
        copyto!(result_storage, samples.data)
    else
        encode!(result_storage, samples.signal.sample_type,
                samples.signal.sample_resolution_in_unit,
                samples.signal.sample_offset_in_unit,
                samples.data, dither_storage)
    end
    return setproperties(samples; data=result_storage, encoded=true, validated=false)
end

#####
##### `decode`/`decode!`
#####

"""
    decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)

Return `sample_resolution_in_unit .* sample_data .+ sample_offset_in_unit`.

If:

```
sample_data isa AbstractArray &&
sample_resolution_in_unit == 1 &&
sample_offset_in_unit == 0
```

then this function is the identity and will return `sample_data` directly without copying.
"""
function decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)
    if sample_data isa AbstractArray
        sample_resolution_in_unit == 1 && sample_offset_in_unit == 0 && return sample_data
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
    decode(samples::Samples)

If `samples.encoded` is `true`, return a `Samples` instance that wraps
`decode(samples.sample_resolution_in_unit, samples.sample_offset_in_unit, samples.data)`.

If `samples.encoded` is `false`, this function is the identity.
"""
function decode(samples::Samples)
    samples.encoded || return samples
    return setproperties(samples;
                         data=decode(samples.sample_resolution_in_unit,
                                     samples.sample_offset_in_unit,
                                     samples.data),
                         encoded=false,
                         validated=false)
end

"""
    decode!(result_storage, samples::Samples)

If `samples.encoded` is `true`, return a `Samples` instance that wraps
`decode!(result_storage, samples.sample_resolution_in_unit, samples.sample_offset_in_unit, samples.data)`.

If `samples.encoded` is `false`, return a `Samples` instance that wraps
`copyto!(result_storage, samples.data)`.
"""
function decode!(result_storage, samples::Samples)
    if samples.encoded
        decode!(result_storage, samples.sample_resolution_in_unit,
                samples.sample_offset_in_unit, samples.data)
    else
        copyto!(result_storage, samples.data)
    end
    return setproperties(samples; data=result_storage, encoded=false, validated=false)
end
