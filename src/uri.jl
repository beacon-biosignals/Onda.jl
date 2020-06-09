# XXX: A lot of the functionality here will currently fail hard on Windows because
# so many path generation/manipulation utilities will default to URI-incompatible
# backslashes as path separators. The tentative plan is to use FilePaths.jl to
# bridge the abstraction gap here between local file paths and URIs in a way
# that is hopefully mostly system independent

#####
##### `TypedURI`
#####

function _populate_missing_uri_fields(uri::URI)
    scheme = isempty(uri.scheme) ? "file" : uri.scheme
    host = isempty(uri.host) ? "localhost" : uri.host
    return URI(uri; scheme=scheme, host=host)
end

struct TypedURI{scheme}
    value::URI
    function TypedURI{scheme}(uri::URI) where {scheme}
        uri = _populate_missing_uri_fields(uri)
        scheme === Symbol(uri.scheme) || throw(ArgumentError("mismatched scheme for TypedURI: $scheme !== $(uri.scheme)"))
        return new{scheme}(uri)
    end
    function TypedURI(uri::URI)
        uri = _populate_missing_uri_fields(uri)
        return new{Symbol(uri.scheme)}(uri)
    end
end

TypedURI(path::AbstractString) = TypedURI{:file}(URI(abspath(path)))

"""
    samples_uri(uri::TypedURI, uuid::UUID)

Return the URI that locates the subdirectory within corresponding to the
recording specified by `uuid`.
"""
function samples_uri(uri::TypedURI{scheme}, uuid::UUID) where scheme
    uuid_path = joinpath(uri.value.path, "samples", uuid)
    return TypedURI{scheme}(URI(uri.value; path=uuid_path))
end

"""
    samples_uri(uri::TypedURI, uuid::UUID, signal_name, file_extension)

Return the URI that locates the requested signal data file in the `samples`
subdirectory corresponding to the recording specified by `uuid`.
"""
function samples_uri(uri::TypedURI{scheme}, uuid::UUID, signal_name, file_extension) where scheme
    file_path = joinpath(uri.value.path, "samples", uuid, string(signal_name, ".", file_extension))
    return TypedURI{{scheme}(URI(uri.value; path=file_path))
end

function read_samples(uri::TypedURI, signal::Signal; serializer=serializer(signal))
    return Samples(signal, true, read_lpcm(uri, serializer))
end

function read_samples(uri::TypedURI, signal::Signal, span::AbstractTimeSpan;
                      serializer=serializer(signal))
    sample_range = index_from_time(signal.sample_rate, span)
    offset, n = first(sample_range) - 1, length(sample_range)
    return Samples(signal, true, read_lpcm(uri, serializer, offset, n))
end

function write_samples(uri::TypedURI, samples::Samples; overwrite::Bool=true,
                       serializer=serializer(samples.signal))
    if !overwrite && isfile(uri.value.path)
        error("overwrite disabled but file exists at path: $(uri.value.path)")
    end
    return write_lpcm(uri, encode(samples).data, serializer)
end

#####
##### `TypedURI{:file}`
#####

function assert_localhost(uri::TypedURI{:file})
    if uri.value.host != "localhost"
        throw(ArgumentError("unexpected non-`localhost` host for URI $(uri): $(uri.value.host)"))
    end
    return nothing
end

function delete(uri::TypedURI{:file})
    assert_localhost(uri)
    rm(uri.value.path; recursive=true, force=true)
    return nothing
end

function read_lpcm(uri::TypedURI{:file}, serializer)
    assert_localhost(uri)
    return deserialize_lpcm(read(uri.value.path), serializer))
end

function read_lpcm(uri::TypedURI{:file}, serializer, offset, n)
    assert_localhost(uri)
    return open(io -> deserialize_lpcm(io, serializer, offset, n), uri.value.path, "r")
end

function write_lpcm(uri::TypedURI{:file}, samples::AbstractMatrix, serializer)
    assert_localhost(uri)
    return open(io -> serialize_lpcm(io, samples, serializer), uri.value.path, "w")
end

"""
    write_recordings_file(uri::TypedURI{:file}, header::Header, recordings::Dict{UUID,Recording})

Overwrite `uri.value.path` with `serialize_recordings_msgpack_zst(header, recordings)`.

Note that an `ArgumentError` will be thrown unless `uri.value.host == "localhost"`.

If `uri.value.path` already exists, this function creates a backup at `\$(uri.value.path).backup` before
overwriting `uri.value.path`; this backup is automatically deleted after the overwrite succeeds.
"""
function write_recordings_file(uri::TypedURI{:file}, header::Header, recordings::Dict{UUID,Recording})
    assert_localhost(uri)
    backup_file_path = string(uri.value.path, ".backup")
    isfile(uri.value.path) && mv(uri.value.path, backup_file_path)
    write(uri.value.path, serialize_recordings_msgpack_zst(header, recordings))
    rm(backup_file_path; force=true)
    return nothing
end

"""
    read_recordings_file(uri::TypedURI{:file})

Return `deserialize_recordings_msgpack_zst(read(uri.path))`.

Note that an `ArgumentError` will be thrown unless `uri.host == "localhost"`.
"""
function read_recordings_file(uri::TypedURI{:file})
    assert_localhost(uri)
    return deserialize_recordings_msgpack_zst(read(uri.value.path))
end
