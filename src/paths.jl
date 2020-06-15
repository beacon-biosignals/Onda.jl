# TODO `write_*` functions here that expect pre-existing intermediate paths
# should take on the responsibility of creating those paths if they don't
# yet exist

# TODO more doc/test

"""
    samples_path(root, uuid::UUID)

Return the path within `joinpath(root, "samples")` corresponding to the recording specified by `uuid`.
"""
samples_path(root, uuid::UUID) = joinpath(root, "samples", string(uuid))

"""
    samples_path(root, uuid::UUID, signal_name, file_extension)

Return the path to the requested signal data file within `samples_path(root, uuid)`.
"""
function samples_path(root, uuid::UUID, signal_name, file_extension)
    return joinpath(samples_path(root, uuid), string(signal_name, ".", file_extension))
end

function read_samples(path, signal::Signal; serializer=serializer(signal))
    return Samples(signal, true, read_lpcm(path, serializer))
end

function read_samples(path, signal::Signal, span::AbstractTimeSpan;
                      serializer=serializer(signal))
    sample_range = index_from_time(signal.sample_rate, span)
    offset, n = first(sample_range) - 1, length(sample_range)
    return Samples(signal, true, read_lpcm(path, serializer, offset, n))
end

function write_samples(path, samples::Samples; overwrite::Bool=true,
                       serializer=serializer(samples.signal))
    return write_lpcm(path, encode(samples).data, serializer)
end

function read_lpcm(path, serializer)
    return deserialize_lpcm(read(path), serializer))
end

function read_lpcm(path, serializer, offset, n)
    return open(io -> deserialize_lpcm(io, serializer, offset, n), path, "r")
end

function write_lpcm(path, samples::AbstractMatrix, serializer; overwrite=true)
    if !overwrite && isfile(path)
        error("overwrite disabled but file exists at path: $path")
    end
    return open(io -> serialize_lpcm(io, samples, serializer), path, "w")
end

"""
    write_recordings_file(path, header::Header, recordings::Dict{UUID,Recording})

Overwrite `path` with `serialize_recordings_msgpack_zst(header, recordings)`.

If `path` already exists, this function creates a backup at `\$path.backup` before
overwriting `path`; this backup is automatically deleted after the overwrite succeeds.
"""
function write_recordings_file(path, header::Header, recordings::Dict{UUID,Recording})
    backup_file_path = string(path, ".backup")
    isfile(path) && mv(path, backup_file_path)
    write(path, serialize_recordings_msgpack_zst(header, recordings))
    rm(backup_file_path; force=true)
    return nothing
end

"""
    read_recordings_file(path)

Return `deserialize_recordings_msgpack_zst(read(path))`.
"""
read_recordings_file(path) = deserialize_recordings_msgpack_zst(read(path))
