#####
##### `Dataset`
#####

const RECORDINGS_FILE_NAME = "recordings.msgpack.zst"

# NOTE: `Dataset` purposefully does not reexpose `typeof(path)` as a type parameter
# in order to prevent downstream method overloads on `Dataset` from dispatching
# on it; such specialization should strictly reside in the Paths API layer (see
# `src/paths.jl`). Also, any resulting dynamic dispatch costs will be quite
# neglible compared to the cost of storage layer interactions.
struct Dataset
    path::Any
    header::Header
    recordings::Dict{UUID,Recording}
end

"""
    Dataset(path)

Return a `Dataset` instance targeting `path` as an Onda dataset, without loading
any content from `path`.
"""
function Dataset(path; create=missing)
    if create isa Bool
        if create
            @warn "`Dataset(path; create=true)` is deprecated; use `save(Dataset(path))` instead"
            return save(Dataset(path))
        else
            @warn "`Dataset(path; create=false)` is deprecated; use `load(path)` instead"
            return load(path)
        end
    end
    return Dataset(path, Header(MAXIMUM_ONDA_FORMAT_VERSION, true), Dict{UUID,Recording}())
end

"""
    load(path)

Return a `Dataset` instance that contains all metadata necessary to read and
write to the Onda dataset stored at `path`. Note that this constuctor loads all
the `Recording` objects contained in `path/recordings.msgpack.zst`.
"""
function load(path)
    header, recordings = read_recordings_file(joinpath(path, RECORDINGS_FILE_NAME))
    return Dataset(path, header, recordings)
end

"""
    save(dataset::Dataset)

Save all metadata content necessary to read/write `dataset` to `dataset.path`.

Note that in-memory mutations to `dataset` will not persist unless followed by
a `save` call. Furthermore, new sample data written to `dataset` via `store!`
will not be readable from freshly loaded copies of `dataset` (e.g.
`load(dataset.path)`) until `save` is called.
"""
function save(dataset::Dataset)
    mkpath(joinpath(dataset.path, "samples"))
    write_recordings_file(joinpath(dataset.path, RECORDINGS_FILE_NAME),
                          dataset.header, dataset.recordings)
    return dataset
end

#####
##### `merge!`
#####

"""
    merge!(destination::Dataset, datasets::Dataset...; only_recordings::Bool=false)

Write all filesystem content and the `recordings` field of each `Dataset` in
`datasets` to `destination`.

If any filesystem content has a name that conflicts with existing filesystem
content in `destination`, this function will throw an error. An error will also
be thrown if this function encounters multiple recordings with the same UUID.

If `only_recordings` is `true`, then only the `recordings` field of each `Dataset`
is merged, such that no filesystem content is read or written.

NOTE: This function is currently only implemented when `only_recordings = true`.
"""
function Base.merge!(destination::Dataset, datasets::Dataset...; only_recordings::Bool=false)
    only_recordings || error("`merge!(datasets::Dataset...; only_recordings=false)` is not yet implemented")
    for dataset in datasets
        for uuid in keys(dataset.recordings)
            if haskey(destination.recordings, uuid)
                throw(ArgumentError("recording $uuid already exists in the destination dataset"))
            end
        end
        merge!(destination.recordings, dataset.recordings)
    end
    return destination
end

#####
##### `create_recording!`
#####

"""
    create_recording!(dataset::Dataset, uuid::UUID=uuid4())

Create `uuid::UUID => recording::Recording`, add the pair to `dataset.recordings`,
and return the pair.
"""
function create_recording!(dataset::Dataset, uuid::UUID=uuid4())
    if haskey(dataset.recordings, uuid)
        throw(ArgumentError("recording with UUID $uuid already exists in dataset"))
    end
    recording = Recording(Dict{Symbol,Signal}(), Set{Annotation}())
    dataset.recordings[uuid] = recording
    return uuid => recording
end

#####
##### `samples_path`
#####

"""
    samples_path(dataset::Dataset, uuid::UUID)

Return `samples_path(dataset.path, uuid)`.
"""
samples_path(dataset::Dataset, uuid::UUID) = samples_path(dataset.path, uuid)

"""
    samples_path(dataset::Dataset, uuid::UUID, signal_name::Symbol)

Return `samples_path(dataset.path, uuid, signal_name, extension)` where `extension`
is defined as `dataset.recordings[uuid].signals[signal_name].file_extension`.
"""
function samples_path(dataset::Dataset, uuid::UUID, signal_name::Symbol)
    file_extension = dataset.recordings[uuid].signals[signal_name].file_extension
    return samples_path(dataset.path, uuid, signal_name, file_extension)
end

#####
##### `load`
#####

"""
    load_encoded(args...)

Supports exactly the same methods as [`load`](@ref), but doesn't automatically call
[`decode`](@ref) on the returned `Samples`.
"""
function load_encoded(dataset::Dataset, uuid::UUID, signal_name::Symbol, span::AbstractTimeSpan...)
    signal = dataset.recordings[uuid].signals[signal_name]
    path = samples_path(dataset.path, uuid, signal_name, signal.file_extension)
    return read_samples(path, signal, span...)
end

function load_encoded(dataset::Dataset, uuid::UUID, signal_names, span::AbstractTimeSpan...)
    return Dict(signal_name => load_encoded(dataset, uuid, signal_name, span...)
                for signal_name in signal_names)
end

function load_encoded(dataset::Dataset, uuid::UUID, span::AbstractTimeSpan...)
    return load_encoded(dataset, uuid, keys(dataset.recordings[uuid].signals), span...)
end

"""
    load(dataset::Dataset, uuid::UUID, signal_name::Symbol[, span::AbstractTimeSpan])

Load, [`decode`](@ref), and return the `Samples` object corresponding to the signal named
`signal_name` in the recording specified by `uuid`.

If `span` is provided, this function returns the equivalent of
`load(dataset, uuid, signal_name)[:, span]`, but potentially avoids loading the
entire signal's worth of sample data if the underlying signal file format and
target storage layer both support partial access/random seeks.

    load(dataset::Dataset, uuid::UUID[, span::AbstractTimeSpan])

Return `load(dataset, uuid, names[, span])` where `names` is a list of all
signal names in the recording specified by `uuid`.

    load(dataset::Dataset, uuid::UUID, signal_names[, span::AbstractTimeSpan])

Return `Dict(signal_name => load(dataset, uuid, signal_name[, span]) for signal_name in signal_names)`.

See also: [`read_samples`](@ref), [`deserialize_lpcm`](@ref)
"""
function load(args...)
    result = load_encoded(args...)
    result isa Dict && return Dict(k => decode(v) for (k, v) in result)
    return result
end

#####
##### `store!`
#####

"""
    store!(dataset::Dataset, uuid::UUID, signal_name::Symbol, samples::Samples;
           overwrite::Bool=true)

Add `signal_name => samples.signal` to `dataset.recordings[uuid].signals` and serialize
`samples.data` to the proper file path within `dataset.path`.

If `overwrite` is `false`, an error is thrown if a signal with `signal_name` already
exists in `dataset.recordings[uuid]`. Otherwise, existing entries matching
`samples.signal` will be deleted and replaced with `samples`.
"""
function store!(dataset::Dataset, uuid::UUID, signal_name::Symbol,
                samples::Samples; overwrite::Bool=true)
    recording, signal = dataset.recordings[uuid], samples.signal
    if haskey(recording.signals, signal_name) && !overwrite
        throw(ArgumentError("$signal_name already exists in $uuid and `overwrite` is `false`"))
    end
    if !is_lower_snake_case_alphanumeric(string(signal_name))
        throw(ArgumentError("$signal_name is not lower snake case and alphanumeric"))
    end
    validate_signal(signal)
    validate_samples(samples)
    duration(signal) == duration(samples) || throw(ArgumentError("duration of `Samples` data does not match `Signal` duration"))
    recording.signals[signal_name] = signal
    write_samples(samples_path(dataset.path, uuid, signal_name, signal.file_extension), samples)
    return recording
end

#####
##### `delete!`
#####

"""
    delete!(dataset::Dataset, uuid::UUID)

Delete the recording whose UUID matches `uuid` from `dataset`. This function
removes the matching `Recording` object from `dataset.recordings`, as well as
deletes the corresponding subdirectory in the `dataset`'s `samples` directory.
"""
function Base.delete!(dataset::Dataset, uuid::UUID)
    delete!(dataset.recordings, uuid)
    rm(samples_path(dataset, uuid); force=true, recursive=true)
    return dataset
end

"""
    delete!(dataset::Dataset, uuid::UUID, signal_name::Symbol)

Delete the signal whose signal_name matches `signal_name` from the recording
whose UUID matches `uuid` in `dataset`. This function removes the matching
`Signal` object from `dataset.recordings[uuid]`, as well as deletes the
corresponding sample data in the `dataset`'s `samples` directory.
"""
function Base.delete!(dataset::Dataset, uuid::UUID, signal_name::Symbol)
    rm(samples_path(dataset, uuid, signal_name); force=true)
    delete!(dataset.recordings[uuid].signals, signal_name)
    return dataset
end
