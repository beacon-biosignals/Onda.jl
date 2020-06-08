#####
##### `TypedURI`
#####
# TODO: restructure implementation of the API underlying the `Dataset` API so
# that the overload points are super clear; that currently implicitly specified
# underlying API layer (e.g. `load_samples`, `samples_path`, etc.) should
# explicitly become the "`TypedURI` API layer".

struct TypedURI{scheme}
    value::URI
    function TypedURI(uri::URI)
        scheme = isempty(uri.scheme) ? "file" : uri.scheme
        host = isempty(uri.host) ? "localhost" : uri.host
        uri = URI(uri; scheme=scheme, host=host)
        return new{Symbol(scheme)}(uri)
    end
end

function assert_localhost(uri::TypedURI{:file})
    uri.host == "localhost" || throw(ArgumentError("unexpected non-`localhost` host for URI $(uri): $(uri.host)"))
    return nothing
end

"""
    write_recordings_file(uri::TypedURI{:file}, header::Header, recordings::Dict{UUID,Recording})

Overwrite `uri.path` with `write_recordings_msgpack_zst(header, recordings)`.

Note that an `ArgumentError` will be thrown unless `uri.host == "localhost"`.

If `uri.path` already exists, this function creates a backup at `\$(uri.path).backup` before overwriting
`uri.path`; this backup is automatically deleted after the overwrite succeeds.
"""
function write_recordings_file(uri::TypedURI{:file}, header::Header, recordings::Dict{UUID,Recording})
    assert_localhost(uri)
    backup_file_path = string(uri.path, ".backup")
    isfile(uri.path) && mv(uri.path, backup_file_path)
    write(uri.path, write_recordings_msgpack_zst(header, recordings))
    rm(backup_file_path; force=true)
    return nothing
end

"""
    read_recordings_file(uri::TypedURI{:file})

Return `read_recordings_msgpack_zst(read(uri.path))`.

Note that an `ArgumentError` will be thrown unless `uri.host == "localhost"`.
"""
function read_recordings_file(uri::TypedURI{:file})
    assert_localhost(uri)
    return read_recordings_msgpack_zst(read(uri.path))
end

"""
    samples_uri(uri::TypedURI{:file}, uuid::UUID)

Return the `samples` subdirectory URI corresponding to the recording specified by `uuid`.
"""
samples_uri(uri::TypedURI{:file}, uuid::UUID) = TypedURI(URI(uri; path=joinpath(uri.path, "samples", uuid)))

"""
    samples_uri(uri::TypedURI{:file}, uuid::UUID, signal_name, file_extension)

TODO
"""
function samples_uri(uri::TypedURI{:file}, uuid::UUID, signal_name, file_extension)
    file_path = joinpath(uri.path, "samples", uuid, string(signal_name, ".", file_extension))
    return TypedURI(URI(uri; path=file_path))
end

#=
TypedURI API functions:
load_samples
store_samples!
delete_samples!
=#
