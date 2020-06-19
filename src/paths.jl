#####
##### utilites
#####

read_byte_range(path, ::Missing, ::Missing) = read(path)

"""
    read_byte_range(path, byte_offset, byte_count)

Return the equivalent `read(path)[(byte_offset + 1):(byte_offset + byte_count)]`,
but try to avoid reading unreturned intermediate bytes. Note that the
effectiveness of this method depends on the type of `path`.
"""
function read_byte_range(path, byte_offset, byte_count)
    return open(path, "r") do io
        jump(io, byte_offset)
        return read(io, byte_count)
    end
end

write_path(path, bytes) = (mkpath(dirname(path)); write(path, bytes))

#####
##### read_recordings_file/write_recordings_file
#####

"""
    write_recordings_file(path, header::Header, recordings::Dict{UUID,Recording})

Write `serialize_recordings_msgpack_zst(header, recordings)` to `path`.
"""
function write_recordings_file(path, header::Header, recordings::Dict{UUID,Recording})
    write_path(path, serialize_recordings_msgpack_zst(header, recordings))
    return nothing
end

"""
    read_recordings_file(path)

Return `deserialize_recordings_msgpack_zst(read(path))`.
"""
read_recordings_file(path) = deserialize_recordings_msgpack_zst(read(path))

#####
##### samples_path
#####

"""
    samples_path(dataset_path, uuid::UUID)

Return the path to the samples subdirectory within `dataset_path` corresponding
to the recording specified by `uuid`.
"""
samples_path(dataset_path, uuid::UUID) = joinpath(dataset_path, "samples", string(uuid))

"""
    samples_path(dataset_path, uuid::UUID, signal_name, file_extension)

Return the path to the sample data within `dataset_path` corresponding to
the given signal information and the recording specified by `uuid`.
"""
function samples_path(dataset_path, uuid::UUID, signal_name, file_extension)
    return joinpath(samples_path(dataset_path, uuid),
                    string(signal_name, ".", file_extension))
end

#####
##### read_samples/write_samples
#####

"""
    read_samples(path, signal::Signal)

Return the `Samples` object described by `signal` and stored at `path`.
"""
function read_samples(path, signal::Signal)
    return Samples(signal, true, read_lpcm(path, serializer(signal)))
end

"""
    read_samples(path, signal::Signal, span::AbstractTimeSpan)

Return `read_samples(path, signal)[:, span]`, but attempt to avoid reading
unreturned intermediate sample data. Note that the effectiveness of this method
depends on the types of both `path` and `serializer(signal)`.
"""
function read_samples(path, signal::Signal, span::AbstractTimeSpan)
    sample_range = index_from_time(signal.sample_rate, span)
    sample_offset, sample_count = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(path, serializer(signal), sample_offset, sample_count)
    return Samples(signal, true, sample_data)
end

"""
    write_samples(path, samples::Samples)

Serialize and write `encode(samples)` to `path`.
"""
function write_samples(path, samples::Samples)
    return write_lpcm(path, encode(samples).data, serializer(samples.signal))
end

#####
##### read_lpcm/write_lpcm
#####

read_lpcm(path, serializer) = deserialize_lpcm(read(path), serializer)

function read_lpcm(path, serializer, sample_offset, sample_count)
    deserialize_requested_samples,
    required_byte_offset,
    required_byte_count = deserialize_lpcm_callback(serializer,
                                                    sample_offset,
                                                    sample_count)
    bytes = read_byte_range(path, required_byte_offset, required_byte_count)
    return deserialize_requested_samples(bytes)
end

write_lpcm(path, data, serializer) = write_path(path, serialize_lpcm(data, serializer))
