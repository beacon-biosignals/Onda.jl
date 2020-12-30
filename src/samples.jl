struct Samples{D<:AbstractMatrix,S<:LPCM_SAMPLE_TYPE_UNION}
    data::D
    encoded::Bool
    kind::String
    channel_names::Vector{String}
    sample_unit::String,
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::Type{S}
    sample_rate::Float64
end

function Samples(data, encoded::Bool, signal::Signal)
    return Samples(data, encoded, signal.kind, signal.channel_names,
                   signal.sample_unit, signal.sample_resolution_in_unit, signal.sample_offset_in_unit,
                   julia_type_from_onda_sample_type(signal.sample_type), signal.sample_rate)
end

# #####
# ##### `Samples`
# #####

# """
#     Samples(signal::Signal, encoded::Bool, data::AbstractMatrix,
#             validate::Bool=Onda.validate_on_construction())

# Return a `Samples` instance with the following fields:

# - `signal::Signal`: The `Signal` object that describes the `Samples` instance.

# - `encoded::Bool`: If `true`, the values in `data` are LPCM-encoded as
#    prescribed by the `Samples` instance's `signal`. If `false`, the values in
#    `data` have been decoded into the `signal`'s canonical units.

# - `data::AbstractMatrix`: A matrix of sample data. The `i` th row of the matrix
#    corresponds to the `i`th channel in `signal.channel_names`, while the `j`th
#    column corresponds to the `j`th multichannel sample.

# - `validate::Bool`: If `true`, [`validate_samples`](@ref) is called on the constructed
#    `Samples` instance before it is returned.

# Note that `getindex` and `view` are defined on `Samples` to accept normal integer
# indices, but also accept channel names for row indices and [`TimeSpan`](@ref)
# values for column indices; see `Onda/examples/tour.jl` for a comprehensive
# set of indexing examples.

# See also: [`encode`](@ref), [`encode!`](@ref), [`decode`](@ref), [`decode!`](@ref)
# """
# struct Samples{D<:AbstractMatrix}
#     signal::Signal
#     encoded::Bool
#     data::D
#     function Samples(signal::Signal, encoded::Bool, data::AbstractMatrix,
#                      validate::Bool=validate_on_construction())
#         samples = new{typeof(data)}(signal, encoded, data)
#         validate && validate_samples(samples)
#         return samples
#     end
# end

# """
#     ==(a::Samples, b::Samples)

# Returns `a.encoded == b.encoded && a.signal == b.signal && a.data == b.data`.
# """
# Base.:(==)(a::Samples, b::Samples) = a.encoded == b.encoded && a.signal == b.signal && a.data == b.data

# """
#     validate_samples(samples::Samples)

# Returns `nothing`, checking that the given `samples` are valid w.r.t. the
# underlying `samples.signal` and the Onda specification's canonical LPCM
# representation. If a violation is found, an `ArgumentError` is thrown.

# Properties that are validated by this function include:

# - encoded element type matches `samples.signal.sample_type`
# - the number of rows of `samples.data` matches the number of channels in `samples.signal`
# """
# function validate_samples(samples::Samples)
#     n_channels = channel_count(samples.signal)
#     n_rows = size(samples.data, 1)
#     if n_channels != n_rows
#         throw(ArgumentError("number of channels in signal ($n_channels) " *
#                             "does not match number of rows in data matrix " *
#                             "($n_rows)"))
#     end
#     if samples.encoded && !(eltype(samples.data) <: samples.signal.sample_type)
#         throw(ArgumentError("signal and encoded data matrix have mismatched element types"))
#     end
#     return nothing
# end

# for f in (:getindex, :view)
#     @eval begin
#         import Base: $f  # required for deprecating methods for functions extended from Base
#         @inline function Base.$f(samples::Samples, rows, columns)
#             rows = row_arguments(samples, rows)
#             columns = column_arguments(samples, columns)
#             signal = rows isa Colon ? samples.signal :
#                      signal_from_template(samples.signal;
#                                           channel_names=samples.signal.channel_names[rows],
#                                           validate=false)
#             return Samples(signal, samples.encoded, $f(samples.data, rows, columns), false)
#         end
#         Base.@deprecate $f(samples::Samples, columns) $f(samples, :, columns)
#     end
# end

# _rangify(i) = i
# _rangify(i::Integer) = i:i

# _indices_fallback(f, samples::Samples, i::Union{Colon,AbstractRange,Integer}) = i
# _indices_fallback(f, samples::Samples, args) = map(x -> f(samples, x), args)

# row_arguments(samples::Samples, args) = _rangify(_row_arguments(samples, args))
# _row_arguments(samples::Samples, args) = _indices_fallback(_row_arguments, samples, args)
# _row_arguments(samples::Samples, name::Symbol) = channel(samples, name)

# column_arguments(samples::Samples, args) = _rangify(_column_arguments(samples, args))
# _column_arguments(samples::Samples, args) = _indices_fallback(_column_arguments, samples, args)
# _column_arguments(samples::Samples, t::Period) = _column_arguments(samples, TimeSpan(t))

# function _column_arguments(samples::Samples, span::AbstractTimeSpan)
#     return index_from_time(samples.signal.sample_rate, span)
# end

# """
#     channel(samples::Samples, name::Symbol)

# Return `channel(samples.signal, name)`.

# This function is useful for indexing rows of `samples.data` by channel names.
# """
# channel(samples::Samples, name::Symbol) = channel(samples.signal, name)

# """
#     channel(samples::Samples, i::Integer)

# Return `channel(samples.signal, i)`.
# """
# channel(samples::Samples, i::Integer) = channel(samples.signal, i)

# """
#     duration(samples::Samples)

# Returns the `Nanosecond` value for which `samples[TimeSpan(0, duration(samples))] == samples.data`.

# !!! warning
#     `duration(samples)` is not generally equivalent to `duration(samples.signal)`;
#     the former is the duration of the entire original signal in the context of its
#     parent recording, whereas the latter is the actual duration of `samples.data`
#     given `samples.signal.sample_rate`.
# """
# duration(samples::Samples) = time_from_index(samples.signal.sample_rate, size(samples.data, 2) + 1)

# """
#     channel_count(samples::Samples)

# Return `channel_count(samples.signal)`.
# """
# channel_count(samples::Samples) = channel_count(samples.signal)

# """
#     sample_count(samples::Samples)

# Return the number of multichannel samples in `samples` (i.e. `size(samples.data, 2)`)

# !!! warning
#     `sample_count(samples)` is not generally equivalent to `sample_count(samples.signal)`;
#     the former is the sample count of the entire original signal in the context of its parent
#     recording, whereas the latter is actual number of multichannel samples in `samples.data`.
# """
# sample_count(samples::Samples) = size(samples.data, 2)

# #####
# ##### encoding utilities
# #####

# const VALID_SAMPLE_TYPE_UNION = Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64}

# function encode_sample(::Type{S}, resolution_in_unit, offset_in_unit, sample_in_unit,
#                        noise=zero(sample_in_unit)) where {S<:VALID_SAMPLE_TYPE_UNION}
#     sample_in_unit += noise
#     isnan(sample_in_unit) && return typemax(S)
#     from_unit = clamp((sample_in_unit - offset_in_unit) / resolution_in_unit, typemin(S), typemax(S))
#     return round(S, from_unit)
# end

# function dither_noise!(rng::AbstractRNG, storage, step)
#     rand!(rng, storage)
#     broadcast!(_dither_noise, storage, storage, step + step, step)
#     return storage
# end

# dither_noise!(storage, step) = dither_noise!(Random.GLOBAL_RNG, storage, step)

# function _dither_noise(x, range, step)
#     rs = range * x
#     if rs < step
#         return sqrt(rs * step) - step
#     else
#         return step - sqrt(range * (1 - x) * step)
#     end
# end

# #####
# ##### `encode`/`encode!`
# #####

# """
#     encode(sample_type::DataType, sample_resolution_in_unit, sample_offset_in_unit,
#            samples, dither_storage=nothing)

# Return a copy of `samples` quantized according to `sample_type`, `sample_resolution_in_unit`,
# and `sample_offset_in_unit`. `sample_type` must be a concrete subtype of `Onda.VALID_SAMPLE_TYPE_UNION`.
# Quantization of an individual sample `s` is performed via:

#     round(S, (s - sample_offset_in_unit) / sample_resolution_in_unit)

# with additional special casing to clip values exceeding the encoding's dynamic range.

# If `dither_storage isa Nothing`, no dithering is applied before quantization.

# If `dither_storage isa Missing`, dither storage is allocated automatically and
# triangular dithering is applied to the signal prior to quantization.

# Otherwise, `dither_storage` must be a container of similar shape and type to
# `samples`. This container is then used to store the random noise needed for the
# triangular dithering process, which is applied to the signal prior to quantization.
# """
# function encode(::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
#                 samples, dither_storage=nothing) where {S}
#     return encode!(similar(samples, S), S, sample_resolution_in_unit, sample_offset_in_unit,
#                    samples, dither_storage)
# end

# """
#     encode!(result_storage, sample_type::DataType, sample_resolution_in_unit,
#             sample_offset_in_unit, samples, dither_storage=nothing)
#     encode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,
#             samples, dither_storage=nothing)

# Similar to `encode(sample_type, sample_resolution_in_unit, sample_offset_in_unit, samples, dither_storage)`,
# but write encoded values to `result_storage` rather than allocating new storage.

# `sample_type` defaults to `eltype(result_storage)` if it is not provided.
# """
# function encode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,
#                  samples, dither_storage=nothing)
#     return encode!(result_storage, eltype(result_storage), sample_resolution_in_unit,
#                    sample_offset_in_unit, samples, dither_storage)
# end

# function encode!(result_storage, ::Type{S}, sample_resolution_in_unit, sample_offset_in_unit,
#                  samples, dither_storage=nothing) where {S}
#     if dither_storage isa Nothing
#         broadcast!(encode_sample, result_storage, S, sample_resolution_in_unit,
#                    sample_offset_in_unit, samples)
#     else
#         if dither_storage isa Missing
#             dither_storage = similar(samples)
#         elseif size(dither_storage) != size(samples)
#             throw(DimensionMismatch("dithering storage container does not match shape of samples"))
#         end
#         dither_noise!(dither_storage, sample_resolution_in_unit)
#         broadcast!(encode_sample, result_storage, S, sample_resolution_in_unit, sample_offset_in_unit,
#                    samples, dither_storage)
#     end
#     return result_storage
# end

# """
#     encode(samples::Samples, dither_storage=nothing)

# If `samples.encoded` is `false`, return a `Samples` instance that wraps:

#     encode(samples.signal.sample_type,
#            samples.signal.sample_resolution_in_unit,
#            samples.signal.sample_offset_in_unit,
#            samples.data, dither_storage)

# If `samples.encoded` is `true`, this function is the identity.
# """
# function encode(samples::Samples, dither_storage=nothing)
#     samples.encoded && return samples
#     data = encode(samples.signal.sample_type,
#                   samples.signal.sample_resolution_in_unit,
#                   samples.signal.sample_offset_in_unit,
#                   samples.data, dither_storage)
#     return Samples(samples.signal, true, data)
# end

# """
#     encode!(result_storage, samples::Samples, dither_storage=nothing)

# If `samples.encoded` is `false`, return a `Samples` instance that wraps:

#     encode!(result_storage,
#             samples.signal.sample_type,
#             samples.signal.sample_resolution_in_unit,
#             samples.signal.sample_offset_in_unit,
#             samples.data, dither_storage)`.

# If `samples.encoded` is `true`, return a `Samples` instance that wraps
# `copyto!(result_storage, samples.data)`.
# """
# function encode!(result_storage, samples::Samples, dither_storage=nothing)
#     if samples.encoded
#         copyto!(result_storage, samples.data)
#         return Samples(samples.signal, samples.encoded, result_storage)
#     end
#     encode!(result_storage, samples.signal.sample_type,
#             samples.signal.sample_resolution_in_unit,
#             samples.signal.sample_offset_in_unit,
#             samples.data, dither_storage)
#     return Samples(samples.signal, true, result_storage)
# end

# #####
# ##### `decode`/`decode!`
# #####

# """
#     decode(sample_resolution_in_unit, sample_offset_in_unit, samples)

# Return `sample_resolution_in_unit .* samples .+ sample_offset_in_unit`
# """
# function decode(sample_resolution_in_unit, sample_offset_in_unit, samples)
#     return sample_resolution_in_unit .* samples .+ sample_offset_in_unit
# end

# """
#     decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, samples)

# Similar to `decode(sample_resolution_in_unit, sample_offset_in_unit, samples)`, but
# write decoded values to `result_storage` rather than allocating new storage.
# """
# function decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, samples)
#     f = x -> sample_resolution_in_unit * x + sample_offset_in_unit
#     return broadcast!(f, result_storage, samples)
# end

# """
#     decode(samples::Samples)

# If `samples.encoded` is `true`, return a `Samples` instance that wraps
# `decode(samples.signal.sample_resolution_in_unit, samples.signal.sample_offset_in_unit, samples.data)`.

# If `samples.encoded` is `false`, this function is the identity.
# """
# function decode(samples::Samples)
#     samples.encoded || return samples
#     data = decode(samples.signal.sample_resolution_in_unit,
#                   samples.signal.sample_offset_in_unit,
#                   samples.data)
#     return Samples(samples.signal, false, data)
# end

# """
#     decode!(result_storage, samples::Samples)

# If `samples.encoded` is `true`, return a `Samples` instance that wraps
# `decode!(result_storage, samples.signal.sample_resolution_in_unit, samples.signal.sample_offset_in_unit, samples.data)`.

# If `samples.encoded` is `false`, return a `Samples` instance that wraps
# `copyto!(result_storage, samples.data)`.
# """
# function decode!(result_storage, samples::Samples)
#     if samples.encoded
#         decode!(result_storage, samples.signal.sample_resolution_in_unit,
#                 samples.signal.sample_offset_in_unit, samples.data)
#         return Samples(samples.signal, false, result_storage)
#     end
#     copyto!(result_storage, samples.data)
#     return Samples(samples.signal, samples.encoded, result_storage)
# end
