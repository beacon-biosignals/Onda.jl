#####
##### SamplesMetadata
#####

struct SamplesMetadata{K<:AbstractString,
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
    function SamplesMetadata(kind::K, channels::C, sample_unit::U,
                             sample_resolution_in_unit::SRU,
                             sample_offset_in_unit::SOU,
                             sample_type, sample_rate;
                             validate::Bool=Onda.validate_on_construction()) where {K,C,U,SRU,SOU}
        T = typeintersect(promote_type(SRU, SOU), LPCM_SAMPLE_TYPE_UNION)
        S = sample_type isa Type ? sample_type : julia_type_from_onda_sample_type(sample_type)
        metadata = new{K,C,U,T,S}(kind, channels, sample_unit,
                                  convert(T, sample_resolution_in_unit),
                                  convert(T, sample_offset_in_unit),
                                  S, convert(Float64, sample_rate))
        validate && Onda.validate(metadata)
        return metadata
    end
end

function SamplesMetadata(; kind, channels, sample_unit,
                         sample_resolution_in_unit, sample_offset_in_unit,
                         sample_type, sample_rate,
                         validate::Bool=Onda.validate_on_construction())
    return SamplesMetadata(kind, channels, sample_unit,
                           sample_resolution_in_unit, sample_offset_in_unit,
                           sample_type, sample_rate; validate)
end

"""
    validate(metadata::SamplesMetadata)

Returns `nothing`, checking that the given `metadata.sample_unit` and `metadata.channels` are
valid w.r.t. the Onda specification. If a violation is found, an `ArgumentError` is thrown.
"""
function validate(metadata::SamplesMetadata)
    is_lower_snake_case_alphanumeric(metadata.sample_unit) || throw(ArgumentError("invalid sample unit (must be lowercase/snakecase/alphanumeric): $(metadata.sample_unit)"))
    for c in metadata.channel_names
        is_lower_snake_case_alphanumeric(c, ('-', '.')) || throw(ArgumentError("invalid channel name (must be lowercase/snakecase/alphanumeric): $c"))
    end
    return nothing
end

function Base.:(==)(a::SamplesMetadata, b::SamplesMetadata)
    return all(name -> getfield(a, name) == getfield(b, name), fieldnames(SamplesMetadata))
end

"""
    channel(m::SamplesMetadata, name)

Return `i` where `m.channels[i] == name`.
"""
channel(m::SamplesMetadata, name) = findfirst(isequal(name), m.channels)

"""
    channel(m::SamplesMetadata, i::Integer)

Return `m.channels[i]`.
"""
channel(m::SamplesMetadata, i::Integer) = m.channels[i]

"""
    channel_count(m::SamplesMetadata)

Return `length(m.channels)`.
"""
channel_count(m::SamplesMetadata) = length(m.channels)

"""
    sample_count(m::SamplesMetadata, duration::Period)

Return the number of multichannel samples that fit within `duration` given `m.sample_rate`.
"""
sample_count(m::SamplesMetadata, duration::Period) = TimeSpans.index_from_time(m.sample_rate, duration) - 1

"""
    sizeof_samples(m::SamplesMetadata, duration::Period)

Returns the expected size (in bytes) of an encoded `Samples` object corresponding to `m` and `duration`:

    sample_count(m, duration) * channel_count(m) * sizeof(m.sample_type)
"""
sizeof_samples(m::SamplesMetadata, duration::Period) = sample_count(m, duration) * channel_count(m) * sizeof(m.sample_type)

#####
##### Samples
#####

"""
    Samples(data::AbstractMatrix, metadata::SamplesMetadata, encoded::Bool;
            validate::Bool=Onda.validate_on_construction())

Return a `Samples` instance with the following fields:

- `data::AbstractMatrix`: A matrix of sample data. The `i` th row of the matrix
  corresponds to the `i`th channel in `metadata.channels`, while the `j`th
  column corresponds to the `j`th multichannel sample.

- `metadata::SamplesMetadata`: The `SamplesMetadata` object that describes the
  `Samples` instance.

- `encoded::Bool`: If `true`, the values in `data` are LPCM-encoded as prescribed
  by the `Samples` instance's `metadata`. If `false`, the values in `data` have
  been decoded into the `metadata`'s canonical units.

If `validate` is `true`, [`Onda.validate`](@ref) is called on the constructed `Samples`
instance before it is returned.

Note that `getindex` and `view` are defined on `Samples` to accept normal integer
indices, but also accept channel names for row indices and [`TimeSpan`](@ref)
values for column indices; see `Onda/examples/tour.jl` for a comprehensive
set of indexing examples.

See also: [`load`](@ref), [`store`](@ref), [`encode`](@ref), [`encode!`](@ref), [`decode`](@ref), [`decode!`](@ref)
"""
struct Samples{D<:AbstractMatrix,M<:SamplesMetadata}
    data::D
    metadata::M
    encoded::Bool
    function Samples(data, metadata::SamplesMetadata, encoded::Bool;
                     validate::Bool=validate_on_construction())
        samples = new{typeof(data),typeof(metadata)}(data, metadata, encoded)
        validate && Onda.validate(samples)
        return samples
    end
end

"""
    ==(a::Samples, b::Samples)

Returns `a.encoded == b.encoded && a.metadata == b.metadata && a.data == b.data`.
"""
Base.:(==)(a::Samples, b::Samples) = a.encoded == b.encoded && a.metadata == b.metadata && a.data == b.data

"""
    validate(samples::Samples)

Returns `nothing`, checking that the given `samples` are valid w.r.t. the
underlying `samples.metadata` and the Onda specification's canonical LPCM
representation. If a violation is found, an `ArgumentError` is thrown.

Properties that are validated by this function include:

- encoded element type matches `samples.metadata.sample_type`
- the number of rows of `samples.data` matches the number of channels in `samples.metadata`
"""
function validate(samples::Samples)
    n_channels = channel_count(samples.metadata)
    n_rows = size(samples.data, 1)
    if n_channels != n_rows
        throw(ArgumentError("number of channels in signal ($n_channels) " *
                            "does not match number of rows in data matrix " *
                            "($n_rows)"))
    end
    if samples.encoded && !(eltype(samples.data) === samples.metadata.sample_type)
        throw(ArgumentError("encoded `samples.data` matrix eltype does not match `samples.metadata.sample_type`"))
    end
    return nothing
end

TimeSpans.istimespan(::Samples) = true
TimeSpans.start(::Samples) = Nanosecond(0)
TimeSpans.stop(samples::Samples) = TimeSpans.time_from_index(samples.metadata.sample_rate, size(samples.data, 2) + 1)

"""
    channel(samples::Samples, name::Symbol)

Return `channel(samples.metadata, name)`.

This function is useful for indexing rows of `samples.data` by channel names.
"""
channel(samples::Samples, name::Symbol) = channel(samples.metadata, name)

"""
    channel(samples::Samples, i::Integer)

Return `channel(samples.metadata, i)`.
"""
channel(samples::Samples, i::Integer) = channel(samples.metadata, i)

"""
    channel_count(samples::Samples)

Return `channel_count(samples.metadata)`.
"""
channel_count(samples::Samples) = channel_count(samples.metadata)

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
            metadata = setproperties(samples.metadata; channels=rows isa Colon ? samples.channels : samples.channels[rows])
            return Samples($f(samples.data, rows, columns), metadata, samples.encoded; validate=false)
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
    TimeSpans.istimespan(x) && return TimeSpans.index_from_time(samples.sample_rate, TimeSpan(x))
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

    sample_type === eltype(sample_data) &&
    sample_resolution_in_unit == 1 &&
    sample_offset_in_unit == 0

then this function will simply return `sample_data` directly without copying/dithering.
"""
function encode(::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
                sample_data, dither_storage=nothing) where {S<:LPCM_SAMPLE_TYPE_UNION}
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

    encode(samples.metadata.sample_type,
           samples.metadata.sample_resolution_in_unit,
           samples.metadata.sample_offset_in_unit,
           samples.data, dither_storage)

If `samples.encoded` is `true`, this function is the identity.
"""
function encode(samples::Samples, dither_storage=nothing)
    samples.encoded && return samples
    return Samples(encode(samples.metadata.sample_type,
                          samples.metadata.sample_resolution_in_unit,
                          samples.metadata.sample_offset_in_unit,
                          samples.data, dither_storage),
                   samples.metadata, true; validate=false)
end

"""
    encode!(result_storage, samples::Samples, dither_storage=nothing)

If `samples.encoded` is `false`, return a `Samples` instance that wraps:

    encode!(result_storage,
            samples.metadata.sample_type,
            samples.metadata.sample_resolution_in_unit,
            samples.metadata.sample_offset_in_unit,
            samples.data, dither_storage)`.

If `samples.encoded` is `true`, return a `Samples` instance that wraps
`copyto!(result_storage, samples.data)`.
"""
function encode!(result_storage, samples::Samples, dither_storage=nothing)
    if samples.encoded
        copyto!(result_storage, samples.data)
    else
        encode!(result_storage, samples.metadata.sample_type,
                samples.metadata.sample_resolution_in_unit,
                samples.metadata.sample_offset_in_unit,
                samples.data, dither_storage)
    end
    return Samples(result_storage, samples.metadata, true; validate=false)
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

    decode(samples.metadata.sample_resolution_in_unit, samples.metadata.sample_offset_in_unit, samples.data)

If `samples.encoded` is `false`, this function is the identity.
"""
function decode(samples::Samples)
    samples.encoded || return samples
    return Samples(decode(samples.metadata.sample_resolution_in_unit,
                          samples.metadata.sample_offset_in_unit,
                          samples.data),
                   samples.metadata, false; validate=false)
end

"""
    decode!(result_storage, samples::Samples)

If `samples.encoded` is `true`, return a `Samples` instance that wraps

    decode!(result_storage, samples.metadata.sample_resolution_in_unit, samples.metadata.sample_offset_in_unit, samples.data)

If `samples.encoded` is `false`, return a `Samples` instance that wraps `copyto!(result_storage, samples.data)`.
"""
function decode!(result_storage, samples::Samples)
    if samples.encoded
        decode!(result_storage, samples.metadata.sample_resolution_in_unit,
                samples.metadata.sample_offset_in_unit, samples.data)
    else
        copyto!(result_storage, samples.data)
    end
    return Samples(result_storage, samples.metadata, false; validate=false)
end
=#