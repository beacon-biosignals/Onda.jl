# TODO `write_*` functions here that expect pre-existing intermediate paths
# should take on the responsibility of creating those paths if they don't
# yet exist

# TODO more doc/test

#####
##### samples_location
#####

samples_location(dataset_location, uuid::UUID) = joinpath(dataset_location, "samples", string(uuid))

function samples_location(dataset_location, uuid::UUID, signal_name, file_extension)
    return joinpath(samples_location(dataset_location, uuid),
                    string(signal_name, ".", file_extension))
end

#####
##### read_samples/write_samples
#####

function read_samples(location, signal::Signal; serializer=serializer(signal))
    return Samples(signal, true, read_lpcm(location, serializer))
end

function read_samples(location, signal::Signal, span::AbstractTimeSpan;
                      serializer=serializer(signal))
    sample_range = index_from_time(signal.sample_rate, span)
    sample_offset, sample_count = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(location, serializer, sample_offset, sample_count)
    return Samples(signal, true, sample_data)
end

function write_samples(location, samples::Samples; overwrite::Bool=true,
                       serializer=serializer(samples.signal))
    return write_lpcm(location, encode(samples).data, serializer)
end

#####
##### read_lpcm/write_lpcm
#####

# TODO restructure deserialize_lpcm to support the following:
#
# function read_lpcm(location, serializer, sample_offset, sample_count)
#     required_byte_range, bytes_to_samples = request_sample_range(serializer, sample_offset, sample_count)
#     bytes = read_location(location, required_byte_range)
#     return bytes_to_samples(bytes)
# end

# read_lpcm(location, serializer) = deserialize_lpcm(read(location), serializer)
#
# function read_lpcm(location, serializer, sample_offset, sample_count)
#     required_byte_range, bytes_to_samples = deserialize_lpcm(serializer, sample_offset, sample_count)
#     bytes = read_location(location, required_byte_range)
#     return bytes_to_samples(bytes)
# end
#
# function read_lpcm(location, serializer, sample_offset, sample_count)
#     return open(location, "r") do io
#         return deserialize_lpcm(io, serializer, sample_offset, sample_count)
#     end
# end
#
# write_lpcm(location, data, serializer) = write(location, serialize_lpcm(data, serializer))

#####
##### read_recordings_file/write_recordings_file
#####

"""
    write_recordings_file(location, header::Header, recordings::Dict{UUID,Recording})

Write `serialize_recordings_msgpack_zst(header, recordings)` to `location`.
"""
function write_recordings_file(location, header::Header, recordings::Dict{UUID,Recording})
    write(location, serialize_recordings_msgpack_zst(header, recordings))
    return nothing
end

"""
    read_recordings_file(location)

Return `deserialize_recordings_msgpack_zst(read(location))`.
"""
read_recordings_file(location) = deserialize_recordings_msgpack_zst(read(location))
