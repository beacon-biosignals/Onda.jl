module Onda

using UUIDs, Dates, Random
using TimeSpans, ConstructionBase
using Arrow, Tables, PrettyTables
using MsgPack, TranscodingStreams, CodecZstd

#####
##### includes/exports
#####

include("utilities.jl")
include("annotations.jl")
include("signals.jl")
include("samples.jl")
include("formats.jl")
include("dataset.jl")

#####
##### upgrades/deprecations
#####

log(message) = println(now(), " | ", message)

function upgrade_onda_format_from_v0_4_to_v0_5!(dataset_path;
                                                verbose=true,
                                                compress=nothing,
                                                uuid_from_annotation = _ -> uuid4(),
                                                signal_file_path = (uuid, kind, ext) -> joinpath("samples", string(uuid), kind * "." * ext),
                                                signal_file_format = (ext, opts) -> ext)
    raw_header, raw_recordings = MsgPack.unpack(zstd_decompress(read(joinpath(dataset_path, "recordings.msgpack.zst"))))
    v"0.3" <= VersionNumber(raw_header["onda_format_version"]) < v"0.5" || error("unexpected dataset version: $(raw_header["onda_format_version"])")
    signals = SignalsRow{String}[]
    annotations = AnnotationsRow{String}[]
    for (i, (uuid, recording)) in enumerate(raw_recordings)
        verbose && log("($i / $(length(raw_recordings))) converting recording $uuid...")
        recording_uuid = UUID(uuid)
        for (kind, signal) in recording["signals"]
            push!(signals, SignalsRow(; recording_uuid,
                                      file_path=signal_file_path(recording_uuid, kind, signal["file_extension"]),
                                      file_format=signal_file_format(signal["file_extension"], signal["file_options"]),
                                      kind,
                                      channels=signal["channel_names"],
                                      start_nanosecond=signal["start_nanosecond"],
                                      stop_nanosecond=signal["stop_nanosecond"],
                                      sample_unit=signal["sample_unit"],
                                      sample_resolution_in_unit=signal["sample_resolution_in_unit"],
                                      sample_offset_in_unit=signal["sample_offset_in_unit"],
                                      sample_type=signal["sample_type"],
                                      sample_rate=signal["sample_rate"]))
        end
        for ann in recording["annotations"]
            push!(annotations, AnnotationsRow(; recording_uuid,
                                              uuid=uuid_from_annotation(ann),
                                              start_nanosecond=ann["start_nanosecond"],
                                              stop_nanosecond=ann["stop_nanosecond"],
                                              value=ann["value"]))
        end
    end
    verbose && log("writing out onda.signals file...")
    signals = Tables.columntable(signals)
    Arrow.setmetadata!(signals, Dict("onda_format_version" => "v0.5.0"))
    Arrow.write(joinpath(dataset_path, "onda.signals"), signals; compress)
    verbose && log("onda.signals file written.")
    verbose && log("writing out onda.annotations file...")
    annotations = Tables.columntable(annotations)
    Arrow.setmetadata!(annotations, Dict("onda_format_version" => "v0.5.0"))
    Arrow.write(joinpath(dataset_path, "onda.annotations"), annotations; compress)
    verbose && log("onda.annotations file written.")
    return signals, annotations
end

end # module
