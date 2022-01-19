module Onda

using Compat: @compat
using UUIDs, Dates, Random, Mmap
using Compat, TimeSpans, Arrow, Tables, TranscodingStreams, CodecZstd
using ConstructionBase # here for deprecations only
using Legolas
using Legolas: @row, write_full_path

include("utilities.jl")

include("annotations.jl")
export Annotation, write_annotations, validate_annotations, merge_overlapping_annotations

include("signals.jl")
export Signal, SamplesInfo, write_signals, validate_signals,
       channel, channel_count, sample_count, sizeof_samples, sample_type

include("serialization.jl")
export AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCMZstFormat,
       format, deserialize_lpcm, serialize_lpcm, deserialize_lpcm_callback,
       deserializing_lpcm_stream, serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, encode, encode!, decode, decode!, load, store

include("deprecations.jl")

end # module
