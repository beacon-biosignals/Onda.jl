module Onda

using UUIDs, Dates, Random, Mmap
using Compat, TimeSpans, Legolas, Arrow, Tables, TranscodingStreams, CodecZstd
using MsgPack, JSON3 # only used to facilitate conversion to/from Onda v0.4 datasets

#####
##### includes/exports
#####

include("utilities.jl")

include("annotations.jl")
export Annotation, merge_overlapping_annotations

include("signals.jl")
export Signal, SamplesInfo, channel, channel_count, sample_count, sizeof_samples

include("serialization.jl")
export AbstractLPCMFormat, AbstractLPCMStream, LPCMFormat, LPCMZstFormat,
       format, deserialize_lpcm, serialize_lpcm, deserialize_lpcm_callback,
       deserializing_lpcm_stream, serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, encode, encode!, decode, decode!, load, store

#####
##### upgrades/deprecations
#####

# TODO deprecate read_signals
# TODO deprecate write_signals
# TODO deprecate read_annotations
# TODO deprecate write_annotations
# TODO deprecate Onda.validate
# TODO deprecate Onda.materialize
# TODO deprecate Onda.gather
# TODO Onda.validate_on_construction

# TODO upgrade/downgrade methods for corresponding OndaFormat update

"""
    upgrade_onda_dataset_to_v0_5!(dataset_path;
                                  verbose=true,
                                  uuid_from_annotation=(_ -> uuid4()),
                                  signal_file_path=((uuid, kind, ext) -> joinpath("samples", string(uuid), kind * "." * ext)),
                                  signal_file_format=((ext, opts) -> ext),
                                  kwargs...)

Upgrade a Onda Format v0.3/v0.4 dataset to Onda Format v0.5 by converting the
dataset's `recordings.msgpack.zst` file into `upgraded.onda.signals.arrow` and
upgraded.onda.annotations.arrow` files written to the root of the dataset (w/o
deleting existing content).

Returns a tuple `(signals, annotations)` where `signals` is the table corresponding
to `upgraded.onda.signals.arrow` and `annotations` is the table corresponding to
`upgraded.onda.annotations.arrow`.

- If `verbose` is `true`, this function will print out timestamped progress logs.

- `uuid_from_annotation` is an function that takes in an Onda Format v0.3/v0.4
  annotation (as a `Dict{String}`) and returns the `id` field to be associated with
  that annotation.

- `signal_file_path` is a function that takes in a signal's recording UUID, the
  signal's kind (formerly the `name` field), and the signal's `file_extension` field
  and returns the `file_path` field to be associated with that signal.

- `signal_file_format` is a function that takes in a signal's `file_extension` field
  and `file_options` field and returns the `file_format` field to be associated with
  that signal.

- `kwargs` is forwarded to internal invocations of `Arrow.write(...; file=true, kwargs...)`
  used to write the `*.arrow` files.

To upgrade a dataset that are older than Onda Format v0.3/v0.4, first use an older version
of Onda.jl to upgrade the dataset to Onda Format v0.3 or above.
"""
function upgrade_onda_dataset_to_v0_5!(dataset_path;
                                       verbose=true,
                                       uuid_from_annotation=(_ -> uuid4()),
                                       signal_file_path=((uuid, kind, ext) -> joinpath("samples", string(uuid), kind * "." * ext)),
                                       signal_file_format=((ext, opts) -> ext),
                                       kwargs...)
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
                                  span=TimeSpan(signal["start_nanosecond"], signal["stop_nanosecond"]),
                                  kind,
                                  channels=signal["channel_names"],
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
    write_signals(signals_file_path, signals; kwargs...)
    verbose && log("$signals_file_path written.")
    annotations_file_path = joinpath(dataset_path, "upgraded.onda.annotations.arrow")
    verbose && log("writing out $annotations_file_path...")
    write_annotations(annotations_file_path, annotations; kwargs...)
    verbose && log("$annotations_file_path written.")
    return signals, annotations
end

_v0_4_json_value_from_annotation(ann) = JSON3.write(Dict(name => getproperty(ann, name) for name in propertynames(ann)
                                                         if !(name in (:recording, :span))))

"""
    downgrade_onda_dataset_to_v0_4!(dataset_path, signals, annotations;
                                    verbose=true,
                                    value_from_annotation=Onda._v0_4_json_value_from_annotation,
                                    signal_file_extension_and_options_from_format=(fmt -> (fmt, nothing)))

Write an Onda-Format-v0.4-compliant `recordings.msgpack.zst` file to `dataset_path` given Onda-Format-v0.5-compliant
`signals` and `annotations` tables.

- This function internally uses `Onda.gather`, and thus expects `signals`/`annotations` to support `view` for
  row extraction. One way to ensure this is the case is to convert `signals`/`annotations` to `DataFrame`s before
  passing them to this function.

- If `verbose` is `true`, this function will print out timestamped progress logs.

- `value_from_annotation` is a function that takes in an `Onda.Annotation` and returns the string that
  should be written out as that annotation's value. By default, this value will be a JSON object string
  whose fields are all fields in the given annotation except for `recording` and `span`.

- `signal_file_extension_and_options_from_format` is a function that takes in `signal.file_format` and
  returns the `file_extension` and `file_options` fields that should be written out for the signal.

Note that this function does not thoroughly validate that sample data files referenced by `signals` are in an
appropriate Onda-Format-v0.4-compliant location (i.e. in `<dataset_path>/samples/<recording UUID>/<kind>.<extension>`).
"""
function downgrade_onda_dataset_to_v0_4!(dataset_path, signals, annotations;
                                         verbose=true,
                                         value_from_annotation=_v0_4_json_value_from_annotation,
                                         signal_file_extension_and_options_from_format=(fmt -> (fmt, nothing)))
    raw_recordings = Dict{String,Dict}()
    recordings = Onda.gather(:recording, signals, annotations)
    for (i, (uuid, (sigs, anns))) in enumerate(recordings)
        verbose && log("($i / $(length(recordings))) converting recording $uuid...")
        raw_sigs = Dict()
        for sig in Tables.rows(sigs)
            sig = Signal(sig)
            ext, opt = signal_file_extension_and_options_from_format(sig.file_format)
            if verbose && !endswith(sig.file_path, joinpath("samples", string(uuid), sig.kind * "." * ext))
                @warn "potentially invalid Onda Format v0.4 sample data file path: $(sig.file_path)"
            end
            raw_sigs[sig.kind] = Dict("start_nanosecond" => TimeSpans.start(sig.span).value,
                                      "stop_nanosecond" => TimeSpans.stop(sig.span).value,
                                      "channel_names" => sig.channels,
                                      "sample_unit" => sig.sample_unit,
                                      "sample_resolution_in_unit" => sig.sample_resolution_in_unit,
                                      "sample_offset_in_unit" => sig.sample_offset_in_unit,
                                      "sample_type" => sig.sample_type,
                                      "sample_rate" => sig.sample_rate,
                                      "file_extension" => ext,
                                      "file_options" => opt)
        end
        raw_anns = Dict[]
        for ann in Tables.rows(anns)
            ann = Annotation(ann)
            push!(raw_anns, Dict("start_nanosecond" => TimeSpans.start(ann.span).value,
                                 "stop_nanosecond" => TimeSpans.stop(ann.span).value,
                                 "value" => value_from_annotation(ann)))
        end
        raw_recordings[string(uuid)] = Dict("signals" => raw_sigs, "annotations" => raw_anns)
    end
    recordings_file_path = joinpath(dataset_path, "recordings.msgpack.zst")
    verbose && log("writing out $recordings_file_path...")
    io = IOBuffer()
    MsgPack.pack(io, [Dict("onda_format_version" => "v0.4.0", "ordered_keys" => false), raw_recordings])
    write(recordings_file_path, zstd_compress(resize!(io.data, io.size)))
    return raw_recordings
end

end # module
