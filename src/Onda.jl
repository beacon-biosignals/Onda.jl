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

include("tables.jl")

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

"""
To upgrade a v0.3/v0.4 dataset to Onda Format v0.5 format.

To upgrade older datasets, first use an older version of Onda.jl to update them to v0.3 or above, then use this function.
"""
function upgrade_onda_dataset_to_v0_5!(dataset_path;
                                       verbose=true,
                                       compress=nothing,
                                       uuid_from_annotation=(_ -> uuid4()),
                                       signal_file_path=((uuid, kind, ext) -> joinpath("samples", string(uuid), kind * "." * ext)),
                                       signal_file_format=((ext, opts) -> ext))
    raw_header, raw_recordings = MsgPack.unpack(zstd_decompress(read(joinpath(dataset_path, "recordings.msgpack.zst"))))
    v"0.3" <= VersionNumber(raw_header["onda_format_version"]) < v"0.5" || error("unexpected dataset version: $(raw_header["onda_format_version"])")
    signals = Signal[]
    annotations = Annotation[]
    for (i, (uuid, raw)) in enumerate(raw_recordings)
        verbose && log("($i / $(length(raw_recordings))) converting recording $uuid...")
        recording = UUID(uuid)
        for (kind, signal) in raw["signals"]
            push!(signals, Signal(; recording,
                                  file_path=signal_file_path(recording, kind, signal["file_extension"]),
                                  file_format=signal_file_format(signal["file_extension"], signal["file_options"]),
                                  kind,
                                  channels=signal["channel_names"],
                                  span=TimeSpan(signal["start_nanosecond"], signal["stop_nanosecond"]),
                                  sample_unit=signal["sample_unit"],
                                  sample_resolution_in_unit=signal["sample_resolution_in_unit"],
                                  sample_offset_in_unit=signal["sample_offset_in_unit"],
                                  sample_type=signal["sample_type"],
                                  sample_rate=signal["sample_rate"]))
        end
        for annotation in raw["annotations"]
            push!(annotations, Annotation(; recording,
                                          id=uuid_from_annotation(annotation),
                                          span=TimeSpan(annotation["start_nanosecond"], annotation["stop_nanosecond"]),
                                          value=annotation["value"]))
        end
    end
    signals_file_path = joinpath(dataset_path, "upgraded.onda.signals.arrow")
    verbose && log("writing out $signals_file_path...")
    write_signals(signals_file_path, signals; compress)
    verbose && log("$signals_file_path written.")
    annotations_file_path = joinpath(dataset_path, "upgraded.onda.annotations.arrow")
    verbose && log("writing out $annotations_file_path...")
    write_annotations(annotations_file_path, annotations; compress)
    verbose && log("$annotations_file_path written.")
    return signals, annotations
end

end # module
