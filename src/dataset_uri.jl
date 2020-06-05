#####
##### `DatasetURI`
#####
# TODO: restructure implementation of the API underlying the `Dataset` API so
# that the overload points are super clear; that currently implicitly specified
# underlying API layer (e.g. `load_samples`, `samples_path`, etc.) should
# explicitly become the "`DatasetURI` API layer".

struct DatasetURI{scheme}
    value::URI
    function DatasetURI(uri::URI)
        scheme = isempty(uri.scheme) ? "file" : uri.scheme
        host = isempty(uri.host) ? "localhost" : uri.host
        uri = URI(uri; scheme=scheme, host=host)
        return new{Symbol(scheme)}(uri)
    end
end

#=
DatasetURI API functions:

write_recordings_file
read_recordings_file
samples_path
load_samples
store_samples!
delete_samples!
=#
