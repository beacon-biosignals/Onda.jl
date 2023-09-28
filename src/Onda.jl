module Onda

using Compat: @compat
using UUIDs, Dates, Random, Mmap
using Compat, Legolas, TimeSpans, Arrow, Tables, TranscodingStreams, CodecZstd
using Legolas: @schema, @version, write_full_path
using Tables: rowmerge

include("utilities.jl")

include("annotations.jl")
export AnnotationV1, AnnotationV1SchemaVersion, MergedAnnotationV1, MergedAnnotationV1SchemaVersion,
       validate_annotations, merge_overlapping_annotations,
       ContextlessAnnotationV1, add_context

include("signals.jl")
export SamplesInfoV2, SamplesInfoV2SchemaVersion, SignalV2, SignalV2SchemaVersion,
       validate_signals, channel, channel_count, sample_count, sizeof_samples, sample_type

include("serialization.jl")
export AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCMZstFormat,
       format, deserialize_lpcm, serialize_lpcm, deserialize_lpcm_callback,
       deserializing_lpcm_stream, serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, encode, encode!, decode, decode!, load, store

include("deprecations.jl")
export Annotation, Signal

end # module
