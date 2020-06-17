# TODO doc/test

#####
##### path interface functions
#####
# TODO turn into actual documentation
#
# All paths handled by Onda must support the following `Base` functions:
#
# - `read`
# - `rm`
# - `abspath`
# - `joinpath`
#
# As well as the following Onda-defined functions:
#
# - `read_byte_range`
# - `write_path`

read_byte_range(path, ::Missing, ::Missing) = read(path)

function read_byte_range(path, byte_offset, byte_count)
    return open(path, "r") do io
        jump(io, byte_offset)
        return read(io, byte_count)
    end
end

write_path(path, bytes) = (mkpath(path); write(path, bytes))

#####
##### samples_path
#####

samples_path(dataset_path, uuid::UUID) = joinpath(dataset_path, "samples", string(uuid))

function samples_path(dataset_path, uuid::UUID, signal_name, file_extension)
    return joinpath(samples_path(dataset_path, uuid),
                    string(signal_name, ".", file_extension))
end

#####
##### read_samples/write_samples
#####

function read_samples(path, signal::Signal)
    return Samples(signal, true, read_lpcm(path, serializer(signal)))
end

function read_samples(path, signal::Signal, span::AbstractTimeSpan)
    sample_range = index_from_time(signal.sample_rate, span)
    sample_offset, sample_count = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(path, serializer(samples.signal),
                            sample_offset, sample_count)
    return Samples(signal, true, sample_data)
end

function write_samples(path, samples::Samples)
    return write_lpcm(path, encode(samples).data, serializer(sample.signal))
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
