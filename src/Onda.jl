module Onda

using UUIDs, Dates, Random
using TimeSpans, ConstructionBase
using Arrow, Tables
using MsgPack, TranscodingStreams, CodecZstd

function __init__()
    Arrow.ArrowTypes.registertype!(TimeSpan, TimeSpan)
end

#####
##### includes/exports
#####

include("utilities.jl")

include("annotations.jl")
export Annotation, read_annotations, write_annotations, merge_overlapping

include("signals.jl")
export Signal, SamplesInfo, read_signals, write_signals,
       channel, channel_count, sample_count, sizeof_samples

include("formats.jl")
export AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCMZstFormat,
       format, deserialize_lpcm, serialize_lpcm, deserialize_lpcm_callback,
       deserializing_lpcm_stream, serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, encode, encode!, decode, decode!, load, store

#####
##### upgrades/deprecations
#####

# TODO: update
# function upgrade_onda_format_from_v0_4_to_v0_5!(dataset_path;
#                                                 verbose=true,
#                                                 compress=nothing,
#                                                 uuid_from_annotation=(_ -> uuid4()),
#                                                 signal_file_path=((uuid, kind, ext) -> joinpath("samples", string(uuid), kind * "." * ext)),
#                                                 signal_file_format=((ext, opts) -> ext))
#     raw_header, raw_recordings = MsgPack.unpack(zstd_decompress(read(joinpath(dataset_path, "recordings.msgpack.zst"))))
#     v"0.3" <= VersionNumber(raw_header["onda_format_version"]) < v"0.5" || error("unexpected dataset version: $(raw_header["onda_format_version"])")
#     signals = SignalsRow{String}[]
#     annotations = AnnotationsRow{String}[]
#     for (i, (uuid, raw)) in enumerate(raw_recordings)
#         verbose && log("($i / $(length(raw_recordings))) converting recording $uuid...")
#         recording = UUID(uuid)
#         for (kind, signal) in recording["signals"]
#             push!(signals, SignalsRow(; recording,
#                                       file_path=signal_file_path(recording, kind, signal["file_extension"]),
#                                       file_format=signal_file_format(signal["file_extension"], signal["file_options"]),
#                                       kind,
#                                       channels=signal["channel_names"],
#                                       span=TimeSpan(signal["start_nanoseconds"], signal["stop_nanoseconds"])
#                                       sample_unit=signal["sample_unit"],
#                                       sample_resolution_in_unit=signal["sample_resolution_in_unit"],
#                                       sample_offset_in_unit=signal["sample_offset_in_unit"],
#                                       sample_type=signal["sample_type"],
#                                       sample_rate=signal["sample_rate"]))
#         end
#         for ann in recording["annotations"]
#             push!(annotations, AnnotationsRow(; recording,
#                                               uuid=uuid_from_annotation(ann),
#                                               start=ann["start"],
#                                               stop=ann["stop"],
#                                               value=ann["value"]))
#         end
#     end
#     verbose && log("writing out onda.signals file...")
#     write_signals(joinpath(dataset_path, "onda.onda.signals.arrow"), signals; compress)
#     verbose && log("onda.signals file written.")
#     verbose && log("writing out onda.annotations file...")
#     write_annotations(joinpath(dataset_path, "onda.onda.annotations.arrow"), annotations; compress)
#     verbose && log("onda.annotations file written.")
#     return signals, annotations
# end

end # module
