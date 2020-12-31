# TODO it's unclear how much of this, if any, is useful compared to just expressing these operations with DataFrames snippets



# #####
# ##### `load`
# #####

# """
#     load_encoded(args...)

# Supports exactly the same methods as [`load`](@ref), but doesn't automatically call
# [`decode`](@ref) on the returned `Samples`.
# """
# function load_encoded(dataset::Dataset, uuid::UUID, signal_name::Symbol, span::AbstractTimeSpan...)
#     signal = dataset.recordings[uuid].signals[signal_name]
#     path = samples_path(dataset.path, uuid, signal_name, signal.file_extension)
#     return read_samples(path, signal, span...)
# end

# function load_encoded(dataset::Dataset, uuid::UUID, signal_names, span::AbstractTimeSpan...)
#     return Dict(signal_name => load_encoded(dataset, uuid, signal_name, span...)
#                 for signal_name in signal_names)
# end

# function load_encoded(dataset::Dataset, uuid::UUID, span::AbstractTimeSpan...)
#     return load_encoded(dataset, uuid, keys(dataset.recordings[uuid].signals), span...)
# end

# """
#     load(dataset::Dataset, uuid::UUID, signal_name::Symbol[, span::AbstractTimeSpan])

# Load, [`decode`](@ref), and return the `Samples` object corresponding to the signal named
# `signal_name` in the recording specified by `uuid`.

# If `span` is provided, this function returns the equivalent of
# `load(dataset, uuid, signal_name)[:, span]`, but potentially avoids loading the
# entire signal's worth of sample data if the underlying signal file format and
# target storage layer both support partial access/random seeks.

#     load(dataset::Dataset, uuid::UUID[, span::AbstractTimeSpan])

# Return `load(dataset, uuid, names[, span])` where `names` is a list of all
# signal names in the recording specified by `uuid`.

#     load(dataset::Dataset, uuid::UUID, signal_names[, span::AbstractTimeSpan])

# Return `Dict(signal_name => load(dataset, uuid, signal_name[, span]) for signal_name in signal_names)`.

# See also: [`read_samples`](@ref), [`deserialize_lpcm`](@ref)
# """
# function load(args...)
#     result = load_encoded(args...)
#     result isa Dict && return Dict(k => decode(v) for (k, v) in result)
#     return decode(result)
# end

# #####
# ##### `store!`
# #####

# """
#     store!(dataset::Dataset, uuid::UUID, signal_name::Symbol, samples::Samples;
#            overwrite::Bool=true)

# Add `signal_name => samples.signal` to `dataset.recordings[uuid].signals` and serialize
# `samples.data` to the proper file path within `dataset.path`.

# If `overwrite` is `false`, an error is thrown if a signal with `signal_name` already
# exists in `dataset.recordings[uuid]`. Otherwise, existing entries matching
# `samples.signal` will be deleted and replaced with `samples`.
# """
# function store!(dataset::Dataset, uuid::UUID, signal_name::Symbol,
#                 samples::Samples; overwrite::Bool=true)
#     recording, signal = dataset.recordings[uuid], samples.signal
#     if haskey(recording.signals, signal_name) && !overwrite
#         throw(ArgumentError("$signal_name already exists in $uuid and `overwrite` is `false`"))
#     end
#     if !is_lower_snake_case_alphanumeric(string(signal_name))
#         throw(ArgumentError("$signal_name is not lower snake case and alphanumeric"))
#     end
#     validate_signal(signal)
#     validate_samples(samples)
#     duration(signal) == duration(samples) || throw(ArgumentError("duration of `Samples` data does not match `Signal` duration"))
#     recording.signals[signal_name] = signal
#     write_samples(samples_path(dataset.path, uuid, signal_name, signal.file_extension), samples)
#     return recording
# end

# #####
# ##### `delete!`
# #####

# """
#     delete!(dataset::Dataset, uuid::UUID)

# Delete the recording whose UUID matches `uuid` from `dataset`. This function
# removes the matching `Recording` object from `dataset.recordings`, as well as
# deletes the corresponding subdirectory in the `dataset`'s `samples` directory.
# """
# function Base.delete!(dataset::Dataset, uuid::UUID)
#     delete!(dataset.recordings, uuid)
#     rm(samples_path(dataset, uuid); force=true, recursive=true)
#     return dataset
# end

# """
#     delete!(dataset::Dataset, uuid::UUID, signal_name::Symbol)

# Delete the signal whose signal_name matches `signal_name` from the recording
# whose UUID matches `uuid` in `dataset`. This function removes the matching
# `Signal` object from `dataset.recordings[uuid]`, as well as deletes the
# corresponding sample data in the `dataset`'s `samples` directory.
# """
# function Base.delete!(dataset::Dataset, uuid::UUID, signal_name::Symbol)
#     rm(samples_path(dataset, uuid, signal_name); force=true)
#     delete!(dataset.recordings[uuid].signals, signal_name)
#     return dataset
# end

# #####
# ##### by_recording
# #####
# # TODO add signals_by for others
# # TODO DRY this code a bit

# function by_recording(signals::Signals, annotations::Annotations{V},
#                       signals_by::Symbol=:type) where {V}
#     signals_by in (:type, :file_path) || throw(ArgumentError("`signals_by` must be `:type` or `:file_path`, got: $signals_by"))
#     recordings = Dict{UUID,NamedTuple{(:signals, :annotations),Tuple{Dict{String,Signal},Dict{UUID,Annotation{V}}}}}()
#     for signal in Tables.rows(signals)
#         recording = get!(() -> (signals = Dict{String,Signal}(), annotations = Dict{UUID,Annotation{V}}()),
#                          recordings, signal.recording_uuid)
#         recording.signals[getproperty(signal, signals_by)] = signal
#     end
#     for annotation in Tables.rows(annotations)
#         recording = get(recordings, annotation.recording_uuid, nothing)
#         recording === nothing && continue
#         recording.annotations[annotation.uuid] = annotation
#     end
#     return recordings
# end

# function by_recording(annotations::Annotations{V}, signals::Signals) where {V}
#     recordings = Dict{UUID,NamedTuple{(:annotations, :signals),Tuple{Dict{UUID,Annotation{V}},Dict{String,Signal}}}}()
#     for annotation in Tables.rows(annotations)
#         recording = get!(() -> (annotations = Dict{UUID,Annotation{V}}(), signals = Dict{String,Signal}()),
#                          recordings, annotation.recording_uuid)
#         recording.annotations[annotation.uuid] = annotation
#     end
#     for signal in Tables.rows(signals)
#         recording = get(recordings, signal.recording_uuid, nothing)
#         recording === nothing && continue
#         recording.signals[signal.type] = signal
#     end
#     return recordings
# end

# function by_recording!(recordings, table, default, attach!)
#     for row in Tables.rows(table)
#         recording = get!(default, recordings, row.recording_uuid)
#         attach!(recording, row)
#     end
#     return recordings
# end

# function by_recording(annotations::Annotations{V}) where {V}
#     recordings = Dict{UUID,Dict{UUID,Annotation{V}}}()
#     for annotation in Tables.rows(annotations)
#         recording = get!(() -> Dict{UUID,Annotation{V}}(), recordings, annotation.recording_uuid)
#         recording[annotation.uuid] = annotation
#     end
#     return recordings
# end

# function by_recording(signals::Signals)
#     recordings = Dict{UUID,Dict{String,Signal}}()
#     for signal in Tables.rows(signals)
#         recording = get!(() -> Dict{String,Signal}(), recordings, signal.recording_uuid)
#         recording[signal.type] = signal
#     end
#     return recordings
# end

# function by_recording(annotations::Annotations{V}) where {V}
#     recordings = Dict{UUID,Dict{UUID,Annotation{V}}}()
#     for annotation in Tables.rows(annotations)
#         recording = get!(() -> Dict{UUID,Annotation{V}}(), recordings, annotation.recording_uuid)
#         recording[annotation.uuid] = annotation
#     end
#     return recordings
# end