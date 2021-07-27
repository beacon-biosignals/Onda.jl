module Onda

using Base: NamedTuple
using UUIDs, Dates, Random, Mmap
using Compat, TimeSpans, Arrow, Tables, TranscodingStreams, CodecZstd
using Legolas
using Legolas: @row

#####
##### includes/exports
#####

include("utilities.jl")

include("annotations.jl")
export Annotation, write_annotations, merge_overlapping_annotations

include("signals.jl")
export Signal, SamplesInfo, write_signals, channel, channel_count, sample_count, sizeof_samples, sample_type

include("serialization.jl")
export AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCMZstFormat,
       format, deserialize_lpcm, serialize_lpcm, deserialize_lpcm_callback,
       deserializing_lpcm_stream, serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, encode, encode!, decode, decode!, load, store

#####
##### upgrades/deprecations
#####

function _deprecated_read_table(io_or_path, schema=nothing)
    table = Legolas.read_arrow(io_or_path)
    schema isa Legolas.Schema && Legolas.validate(table, schema)
    return table
end

function read_signals(io_or_path; validate_schema::Bool=true)
    @warn "`Onda.read_signals(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead"
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.signal@1") : nothing)
end
export read_signals

function read_annotations(io_or_path; validate_schema::Bool=true)
    @warn "`Onda.read_annotations(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead"
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.annotation@1") : nothing)
end
export read_annotations

@deprecate materialize Legolas.materialize
@deprecate gather Legolas.gather
@deprecate validate_on_construction validate_samples_on_construction
@deprecate Annotation(recording, id, span; custom...) Annotation(; recording, id, span, custom...)
@deprecate(Signal(recording, file_path, file_format, span, kind, channels, sample_unit,
                  sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
                  custom...),
           Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
                  sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                  custom...))
@deprecate(SamplesInfo(kind, channels, sample_unit,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate; custom...),
           SamplesInfo(; kind, channels, sample_unit,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate, custom...))

function validate(::SamplesInfo)
    @warn "validate(::SamplesInfo) is deprecated; avoid invoking this method in favor of calling `validate(::Samples)`"
    return nothing
end

end # module
