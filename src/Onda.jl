module Onda

using UUIDs, Dates, Random
using MsgPack
using TranscodingStreams
using CodecZstd

#####
##### includes/exports
#####

include("utilities.jl")

include("timespans.jl")
export AbstractTimeSpan, TimeSpan, contains, overlaps, shortest_timespan_containing,
       index_from_time, time_from_index, duration

include("recordings.jl")
export Recording, Signal, validate_signal, signal_from_template, Annotation,
       annotate!, span, set_span!, sizeof_samples

include("serialization.jl")
export AbstractLPCMFormat, format, deserialize_recordings_msgpack_zst,
       serialize_recordings_msgpack_zst, deserialize_lpcm, serialize_lpcm,
       deserialize_lpcm_callback, LPCM, LPCMZst, deserializing_lpcm_stream
       serializing_lpcm_stream, finalize_lpcm_stream

include("samples.jl")
export Samples, validate_samples, encode, encode!, decode, decode!, channel,
       channel_count, sample_count

include("paths.jl")
export read_recordings_file, write_recordings_file, samples_path,
       read_samples, write_samples

include("dataset.jl")
export Dataset, create_recording!, load, save, store!, delete!

include("printing.jl")

#####
##### upgrades/deprecations
#####

#= TODO deprecate:
zstd_compress(writer, io) -> nothing
zstd_decompress(reader, io) -> nothing

serializer -> format
serializer_constructor_for_file_extension -> format_constructor_for_file_extension

deserialize_lpcm(bytes, serializer, args...) -> deserialize_lpcm(bytes, format, args...)
deserialize_lpcm(io, serializer, args...) -> deserialize_lpcm(stream, args...)

serialize_lpcm(samples, serializer) -> serialize_lpcm(format, samples)
serialize_lpcm(samples, io, serializer) -> serialize_lpcm(stream, samples)
=#


@deprecate(samples_path(dataset::Dataset, uuid::UUID, signal_name, file_extension),
           samples_path(dataset.path, uuid, signal_name, file_extension))

@deprecate load_samples(path, signal) read_samples(path, signal)
@deprecate load_samples(path, signal, span) read_samples(path, signal, span)

@deprecate store_samples!(path, samples) write_samples(path, samples)

@deprecate(read_recordings_msgpack_zst(bytes::Vector{UInt8}),
           deserialize_recordings_msgpack_zst(bytes))
@deprecate read_recordings_msgpack_zst(path) read_recordings_file(path)

@deprecate(write_recordings_msgpack_zst(header, recodings),
           serialize_recordings_msgpack_zst(header, recodings))
@deprecate(write_recordings_msgpack_zst(path, header, recodings),
           write_recordings_file(path, header, recodings))

@deprecate save_recordings_file save

@deprecate set_duration!(dataset, uuid, duration) begin
    r = dataset.recordings[uuid]
    set_span!(r, TimeSpan(Nanosecond(0), duration))
    r
end

"""
    Onda.upgrade_onda_format_from_v0_2_to_v0_3!(path, combine_annotation_key_value)

Upgrade the Onda v0.2 dataset at `path` to a Onda v0.3 dataset, returning the
upgraded `Dataset`. This upgrade process overwrites `path/recordings.msgpack.zst`
with a v0.3-compliant version of this file; for safety's sake, the old v0.2 file
is preserved at `path/old.recordings.msgpack.zst.backup`.

A couple of the Onda v0.2 -> v0.3 changes require some special handling:

- The `custom` field was removed from recording objects. This function thus writes out
  a file at `path/recordings_custom.msgpack.zst` that contains a map of UUIDs to
  corresponding recordings' `custom` values before deleting the `custom` field. This
  file can be deserialized via `MsgPack.unpack(Onda.zstd_decompress(read("recordings_custom.msgpack.zst")))`.

- Annotations no longer have a `key` field. Thus, each annotation's existing `key` and `value`
  fields are combined into the single new `value` field via the provided callback
  `combine_annotation_key_value(annotation_key, annotation_value)`.
"""
function upgrade_onda_format_from_v0_2_to_v0_3!(path, combine_annotation_key_value)
    file_path = joinpath(path, "recordings.msgpack.zst")
    bytes = zstd_decompress(read(file_path))
    mv(file_path, joinpath(path, "old.recordings.msgpack.zst.backup"))
    io = IOBuffer(bytes)
    read(io, UInt8) == 0x92 || error("corrupt recordings.msgpack.zst")
    header = MsgPack.unpack(io, Header)
    v"0.2" <= header.onda_format_version < v"0.3" || error("unsupported original onda_format_version: $(header.onda_format_version)")
    recordings = MsgPack.unpack(io, Dict{UUID,Any})
    customs = Dict{UUID,Any}(uuid => recording["custom"] for (uuid, recording) in recordings)
    write(joinpath(path, "recordings_custom.msgpack.zst"), zstd_compress(MsgPack.pack(customs)))
    for (uuid, recording) in recordings
        signal_stop_nanosecond = recording["duration_in_nanoseconds"]
        for signal in values(recording["signals"])
            signal["start_nanosecond"] = 0
            signal["stop_nanosecond"] = signal_stop_nanosecond
            signal["sample_offset_in_unit"] = 0.0
            signal["sample_rate"] = float(signal["sample_rate"])
        end
        for annotation in recording["annotations"]
            annotation["value"] = combine_annotation_key_value(annotation["key"], annotation["value"])
            delete!(annotation, "key")
        end
        delete!(recording, "duration_in_nanoseconds")
        delete!(recording, "custom")
    end
    fixed_recordings = MsgPack.unpack(MsgPack.pack(recordings), Dict{UUID,Recording})
    dataset = Dataset(path, Header(v"0.3.0", true), fixed_recordings)
    save(dataset)
    return dataset
end

end # module
