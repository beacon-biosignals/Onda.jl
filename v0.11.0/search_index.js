var documenterSearchIndex = {"docs":
[{"location":"#API-Documentation-1","page":"API Documentation","title":"API Documentation","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Below is the documentation for all functions exported by Onda.jl. For general information regarding the Onda format, please see beacon-biosignals/OndaFormat.","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"CurrentModule = Onda","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Note that Onda.jl's API follows a specific philosophy with respect to property access: users are generally expected to access fields via Julia's object.fieldname syntax, but should only mutate objects via the exposed API methods documented below.","category":"page"},{"location":"#Dataset-API-1","page":"API Documentation","title":"Dataset API","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Dataset\nload\nload_encoded\nsave\ncreate_recording!\nstore!\ndelete!\nOnda.validate_on_construction","category":"page"},{"location":"#Onda.Dataset","page":"API Documentation","title":"Onda.Dataset","text":"Dataset(path)\n\nReturn a Dataset instance targeting path as an Onda dataset, without loading any content from path.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.load","page":"API Documentation","title":"Onda.load","text":"load(path)\n\nReturn a Dataset instance that contains all metadata necessary to read and write to the Onda dataset stored at path. Note that this constuctor loads all the Recording objects contained in path/recordings.msgpack.zst.\n\n\n\n\n\nload(dataset::Dataset, uuid::UUID, signal_name::Symbol[, span::AbstractTimeSpan])\n\nLoad, decode, and return the Samples object corresponding to the signal named signal_name in the recording specified by uuid.\n\nIf span is provided, this function returns the equivalent of load(dataset, uuid, signal_name)[:, span], but potentially avoids loading the entire signal's worth of sample data if the underlying signal file format and target storage layer both support partial access/random seeks.\n\nload(dataset::Dataset, uuid::UUID[, span::AbstractTimeSpan])\n\nReturn load(dataset, uuid, names[, span]) where names is a list of all signal names in the recording specified by uuid.\n\nload(dataset::Dataset, uuid::UUID, signal_names[, span::AbstractTimeSpan])\n\nReturn Dict(signal_name => load(dataset, uuid, signal_name[, span]) for signal_name in signal_names).\n\nSee also: read_samples, deserialize_lpcm\n\n\n\n\n\n","category":"function"},{"location":"#Onda.load_encoded","page":"API Documentation","title":"Onda.load_encoded","text":"load_encoded(args...)\n\nSupports exactly the same methods as load, but doesn't automatically call decode on the returned Samples.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.save","page":"API Documentation","title":"Onda.save","text":"save(dataset::Dataset)\n\nSave all metadata content necessary to read/write dataset to dataset.path.\n\nNote that in-memory mutations to dataset will not persist unless followed by a save call. Furthermore, new sample data written to dataset via store! will not be readable from freshly loaded copies of dataset (e.g. load(dataset.path)) until save is called.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.create_recording!","page":"API Documentation","title":"Onda.create_recording!","text":"create_recording!(dataset::Dataset, uuid::UUID=uuid4())\n\nCreate uuid::UUID => recording::Recording, add the pair to dataset.recordings, and return the pair.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.store!","page":"API Documentation","title":"Onda.store!","text":"store!(dataset::Dataset, uuid::UUID, signal_name::Symbol, samples::Samples;\n       overwrite::Bool=true)\n\nAdd signal_name => samples.signal to dataset.recordings[uuid].signals and serialize samples.data to the proper file path within dataset.path.\n\nIf overwrite is false, an error is thrown if a signal with signal_name already exists in dataset.recordings[uuid]. Otherwise, existing entries matching samples.signal will be deleted and replaced with samples.\n\n\n\n\n\n","category":"function"},{"location":"#Base.delete!","page":"API Documentation","title":"Base.delete!","text":"delete!(dataset::Dataset, uuid::UUID)\n\nDelete the recording whose UUID matches uuid from dataset. This function removes the matching Recording object from dataset.recordings, as well as deletes the corresponding subdirectory in the dataset's samples directory.\n\n\n\n\n\ndelete!(dataset::Dataset, uuid::UUID, signal_name::Symbol)\n\nDelete the signal whose signalname matches `signalnamefrom the recording whose UUID matchesuuidindataset. This function removes the matchingSignalobject fromdataset.recordings[uuid], as well as deletes the corresponding sample data in thedataset'ssamples` directory.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.validate_on_construction","page":"API Documentation","title":"Onda.validate_on_construction","text":"Onda.validate_on_construction()\n\nIf this function returns true, Onda objects will be validated upon construction for compliance with the Onda specification.\n\nIf this function returns false, no such validation will be performed upon construction.\n\nUsers may interactively redefine this method in order to attempt to read malformed Onda datasets.\n\nReturns true by default.\n\nSee also: validate_signal, validate_samples\n\n\n\n\n\n","category":"function"},{"location":"#Onda-Format-Metadata-1","page":"API Documentation","title":"Onda Format Metadata","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Signal\nvalidate_signal\nsignal_from_template\nspan\nsizeof_samples\nAnnotation\nRecording\nset_span!\nannotate!","category":"page"},{"location":"#Onda.Signal","page":"API Documentation","title":"Onda.Signal","text":"Signal\n\nA type representing an individual Onda signal object. Instances contain the following fields, following the Onda specification for signal objects:\n\nchannel_names::Vector{Symbol}\nstart_nanosecond::Nanosecond\nstop_nanosecond::Nanosecond\nsample_unit::Symbol\nsample_resolution_in_unit::Float64\nsample_offset_in_unit::Float64\nsample_type::DataType\nsample_rate::Float64\nfile_extension::Symbol\nfile_options::Union{Nothing,Dict{Symbol,Any}}\n\nIf validate_on_construction returns true, validate_signal is called on all new Signal instances upon construction.\n\nSimilarly to the TimeSpan constructor, this constructor will add a single Nanosecond to stop_nanosecond if start_nanosecond == stop_nanosecond.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.validate_signal","page":"API Documentation","title":"Onda.validate_signal","text":"validate_signal(signal::Signal)\n\nReturns nothing, checking that the given signal is valid w.r.t. the Onda specification. If a violation is found, an ArgumentError is thrown.\n\nProperties that are validated by this function include:\n\nsample_type is a valid Onda sample type\nsample_unit name is lowercase, snakecase, and alphanumeric\nstart_nanosecond/stop_nanosecond form a valid time span\nchannel names are lowercase, snakecase, and alphanumeric\n\n\n\n\n\n","category":"function"},{"location":"#Onda.signal_from_template","page":"API Documentation","title":"Onda.signal_from_template","text":"signal_from_template(signal::Signal;\n                     channel_names=signal.channel_names,\n                     start_nanosecond=signal.start_nanosecond,\n                     stop_nanosecond=signal.stop_nanosecond,\n                     sample_unit=signal.sample_unit,\n                     sample_resolution_in_unit=signal.sample_resolution_in_unit,\n                     sample_offset_in_unit=signal.sample_offset_in_unit,\n                     sample_type=signal.sample_type,\n                     sample_rate=signal.sample_rate,\n                     file_extension=signal.file_extension,\n                     file_options=signal.file_options,\n                     validate=Onda.validate_on_construction())\n\nReturn a Signal where each field is mapped to the corresponding keyword argument.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.span","page":"API Documentation","title":"Onda.span","text":"span(signal::Signal)\n\nReturn TimeSpan(signal.start_nanosecond, signal.stop_nanosecond).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.sizeof_samples","page":"API Documentation","title":"Onda.sizeof_samples","text":"sizeof_samples(signal::Signal)\n\nReturns the expected size (in bytes) of the encoded Samples object corresponding to the entirety of signal:\n\nsample_count(signal) * channel_count(signal) * sizeof(signal.sample_type)\n\n\n\n\n\n","category":"function"},{"location":"#Onda.Annotation","page":"API Documentation","title":"Onda.Annotation","text":"Annotation <: AbstractTimeSpan\n\nA type representing an individual Onda annotation object. Instances contain the following fields, following the Onda specification for annotation objects:\n\nvalue::String\nstart_nanosecond::Nanosecond\nstop_nanosecond::Nanosecond\n\nSimilarly to the TimeSpan constructor, this constructor will add a single Nanosecond to stop_nanosecond if start_nanosecond == stop_nanosecond.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.Recording","page":"API Documentation","title":"Onda.Recording","text":"Recording\n\nA type representing an individual Onda recording object. Instances contain the following fields, following the Onda specification for recording objects:\n\nsignals::Dict{Symbol,Signal}\nannotations::Set{Annotation}\n\n\n\n\n\n","category":"type"},{"location":"#Onda.set_span!","page":"API Documentation","title":"Onda.set_span!","text":"set_span!(recording::Recording, name::Symbol, span::AbstractTimeSpan)\n\nReplace recording.signals[name] with a copy that has the start_nanosecond and start_nanosecond fields set to match the provided span. Returns the newly constructed Signal instance.\n\n\n\n\n\nset_span!(recording::Recording, span::TimeSpan)\n\nReturn Dict(name => set_span!(recording, name, span) for name in keys(recording.signals))\n\n\n\n\n\n","category":"function"},{"location":"#Onda.annotate!","page":"API Documentation","title":"Onda.annotate!","text":"annotate!(recording::Recording, annotation::Annotation)\n\nReturns push!(recording.annotations, annotation).\n\n\n\n\n\n","category":"function"},{"location":"#Samples-1","page":"API Documentation","title":"Samples","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Samples\n==(::Samples, ::Samples)\nvalidate_samples\nchannel\nchannel_count\nsample_count\nencode\nencode!\ndecode\ndecode!","category":"page"},{"location":"#Onda.Samples","page":"API Documentation","title":"Onda.Samples","text":"Samples(signal::Signal, encoded::Bool, data::AbstractMatrix,\n        validate::Bool=Onda.validate_on_construction())\n\nReturn a Samples instance with the following fields:\n\nsignal::Signal: The Signal object that describes the Samples instance.\nencoded::Bool: If true, the values in data are LPCM-encoded as  prescribed by the Samples instance's signal. If false, the values in  data have been decoded into the signal's canonical units.\ndata::AbstractMatrix: A matrix of sample data. The i th row of the matrix  corresponds to the ith channel in signal.channel_names, while the jth  column corresponds to the jth multichannel sample.\nvalidate::Bool: If true, validate_samples is called on the constructed  Samples instance before it is returned.\n\nNote that getindex and view are defined on Samples to accept normal integer indices, but also accept channel names for row indices and TimeSpan values for column indices; see Onda/examples/tour.jl for a comprehensive set of indexing examples.\n\nSee also: encode, encode!, decode, decode!\n\n\n\n\n\n","category":"type"},{"location":"#Base.:==-Tuple{Samples,Samples}","page":"API Documentation","title":"Base.:==","text":"==(a::Samples, b::Samples)\n\nReturns a.encoded == b.encoded && a.signal == b.signal && a.data == b.data.\n\n\n\n\n\n","category":"method"},{"location":"#Onda.validate_samples","page":"API Documentation","title":"Onda.validate_samples","text":"validate_samples(samples::Samples)\n\nReturns nothing, checking that the given samples are valid w.r.t. the underlying samples.signal and the Onda specification's canonical LPCM representation. If a violation is found, an ArgumentError is thrown.\n\nProperties that are validated by this function include:\n\nencoded element type matches samples.signal.sample_type\nthe number of rows of samples.data matches the number of channels in samples.signal\n\n\n\n\n\n","category":"function"},{"location":"#Onda.channel","page":"API Documentation","title":"Onda.channel","text":"channel(signal::Signal, name::Symbol)\n\nReturn i where signal.channel_names[i] == name.\n\n\n\n\n\nchannel(signal::Signal, i::Integer)\n\nReturn signal.channel_names[i].\n\n\n\n\n\nchannel(samples::Samples, name::Symbol)\n\nReturn channel(samples.signal, name).\n\nThis function is useful for indexing rows of samples.data by channel names.\n\n\n\n\n\nchannel(samples::Samples, i::Integer)\n\nReturn channel(samples.signal, i).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.channel_count","page":"API Documentation","title":"Onda.channel_count","text":"channel_count(signal::Signal)\n\nReturn length(signal.channel_names).\n\n\n\n\n\nchannel_count(samples::Samples)\n\nReturn channel_count(samples.signal).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.sample_count","page":"API Documentation","title":"Onda.sample_count","text":"sample_count(signal::Signal)\n\nReturn the number of multichannel samples that fit within duration(signal) given signal.sample_rate.\n\n\n\n\n\nsample_count(samples::Samples)\n\nReturn the number of multichannel samples in samples (i.e. size(samples.data, 2))\n\nwarning: Warning\nsample_count(samples) is not generally equivalent to sample_count(samples.signal); the former is the sample count of the entire original signal in the context of its parent recording, whereas the latter is actual number of multichannel samples in samples.data.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.encode","page":"API Documentation","title":"Onda.encode","text":"encode(sample_type::DataType, sample_resolution_in_unit, sample_offset_in_unit,\n       samples, dither_storage=nothing)\n\nReturn a copy of samples quantized according to sample_type, sample_resolution_in_unit, and sample_offset_in_unit. sample_type must be a concrete subtype of Onda.VALID_SAMPLE_TYPE_UNION. Quantization of an individual sample s is performed via:\n\nround(S, (s - sample_offset_in_unit) / sample_resolution_in_unit)\n\nwith additional special casing to clip values exceeding the encoding's dynamic range.\n\nIf dither_storage isa Nothing, no dithering is applied before quantization.\n\nIf dither_storage isa Missing, dither storage is allocated automatically and triangular dithering is applied to the signal prior to quantization.\n\nOtherwise, dither_storage must be a container of similar shape and type to samples. This container is then used to store the random noise needed for the triangular dithering process, which is applied to the signal prior to quantization.\n\n\n\n\n\nencode(samples::Samples, dither_storage=nothing)\n\nIf samples.encoded is false, return a Samples instance that wraps:\n\nencode(samples.signal.sample_type,\n       samples.signal.sample_resolution_in_unit,\n       samples.signal.sample_offset_in_unit,\n       samples.data, dither_storage)\n\nIf samples.encoded is true, this function is the identity.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.encode!","page":"API Documentation","title":"Onda.encode!","text":"encode!(result_storage, sample_type::DataType, sample_resolution_in_unit,\n        sample_offset_in_unit, samples, dither_storage=nothing)\nencode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,\n        samples, dither_storage=nothing)\n\nSimilar to encode(sample_type, sample_resolution_in_unit, sample_offset_in_unit, samples, dither_storage), but write encoded values to result_storage rather than allocating new storage.\n\nsample_type defaults to eltype(result_storage) if it is not provided.\n\n\n\n\n\nencode!(result_storage, samples::Samples, dither_storage=nothing)\n\nIf samples.encoded is false, return a Samples instance that wraps:\n\nencode!(result_storage,\n        samples.signal.sample_type,\n        samples.signal.sample_resolution_in_unit,\n        samples.signal.sample_offset_in_unit,\n        samples.data, dither_storage)`.\n\nIf samples.encoded is true, return a Samples instance that wraps copyto!(result_storage, samples.data).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.decode","page":"API Documentation","title":"Onda.decode","text":"decode(sample_resolution_in_unit, sample_offset_in_unit, samples)\n\nReturn sample_resolution_in_unit .* samples .+ sample_offset_in_unit\n\n\n\n\n\ndecode(samples::Samples)\n\nIf samples.encoded is true, return a Samples instance that wraps decode(samples.signal.sample_resolution_in_unit, samples.signal.sample_offset_in_unit, samples.data).\n\nIf samples.encoded is false, this function is the identity.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.decode!","page":"API Documentation","title":"Onda.decode!","text":"decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, samples)\n\nSimilar to decode(sample_resolution_in_unit, sample_offset_in_unit, samples), but write decoded values to result_storage rather than allocating new storage.\n\n\n\n\n\ndecode!(result_storage, samples::Samples)\n\nIf samples.encoded is true, return a Samples instance that wraps decode!(result_storage, samples.signal.sample_resolution_in_unit, samples.signal.sample_offset_in_unit, samples.data).\n\nIf samples.encoded is false, return a Samples instance that wraps copyto!(result_storage, samples.data).\n\n\n\n\n\n","category":"function"},{"location":"#AbstractTimeSpan-1","page":"API Documentation","title":"AbstractTimeSpan","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"AbstractTimeSpan\nTimeSpan\ncontains\noverlaps\nshortest_timespan_containing\nduration\ntime_from_index\nindex_from_time","category":"page"},{"location":"#Onda.AbstractTimeSpan","page":"API Documentation","title":"Onda.AbstractTimeSpan","text":"AbstractTimeSpan\n\nA type repesenting a continuous, inclusive span between two points in time.\n\nAll subtypes of AbstractTimeSpan must implement:\n\nfirst(::AbstractTimeSpan)::Nanosecond: return the first nanosecond contained in span\nlast(::AbstractTimeSpan)::Nanosecond: return the last nanosecond contained in span\n\nFor convenience, many Onda functions that accept AbstractTimeSpan values also accept Dates.Period values.\n\nSee also: TimeSpan\n\n\n\n\n\n","category":"type"},{"location":"#Onda.TimeSpan","page":"API Documentation","title":"Onda.TimeSpan","text":"TimeSpan(first, last)\n\nReturn TimeSpan(Nanosecond(first), Nanosecond(last))::AbstractTimeSpan.\n\nIf first == last, a single Nanosecond is added to last since last is an exclusive upper bound and Onda only supports up to nanosecond precision anyway. This behavior also avoids most practical forms of potential breakage w.r.t to legacy versions of Onda that accidentally allowed the construction of TimeSpans where first == last.\n\nSee also: AbstractTimeSpan\n\n\n\n\n\n","category":"type"},{"location":"#Onda.contains","page":"API Documentation","title":"Onda.contains","text":"contains(a::AbstractTimeSpan, b::AbstractTimeSpan)\n\nReturn true if the timespan b lies entirely within the timespan a, return false otherwise.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.overlaps","page":"API Documentation","title":"Onda.overlaps","text":"overlaps(a, b)\n\nReturn true if the timespan a and the timespan b overlap, return false otherwise.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.shortest_timespan_containing","page":"API Documentation","title":"Onda.shortest_timespan_containing","text":"shortest_timespan_containing(spans)\n\nReturn the shortest possible TimeSpan containing all timespans in spans.\n\nspans is assumed to be an iterable of timespans.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.duration","page":"API Documentation","title":"Onda.duration","text":"duration(span)\n\nReturn the duration of span as a Period.\n\nFor span::AbstractTimeSpan, this is equivalent to last(span) - first(span).\n\nFor span::Period, this function is the identity.\n\n\n\n\n\nduration(signal::Signal)\n\nReturn duration(span(signal)).\n\n\n\n\n\nduration(recording::Recording)\n\nReturns maximum(s -> s.stop_nanosecond, values(recording.signals)); throws an ArgumentError if recording.signals is empty.\n\n\n\n\n\nduration(samples::Samples)\n\nReturns the Nanosecond value for which samples[TimeSpan(0, duration(samples))] == samples.data.\n\nwarning: Warning\nduration(samples) is not generally equivalent to duration(samples.signal); the former is the duration of the entire original signal in the context of its parent recording, whereas the latter is the actual duration of samples.data given samples.signal.sample_rate.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.time_from_index","page":"API Documentation","title":"Onda.time_from_index","text":"time_from_index(sample_rate, sample_index)\n\nGiven sample_rate in Hz and assuming sample_index > 0, return the earliest Nanosecond containing sample_index.\n\nExamples:\n\njulia> time_from_index(1, 1)\n0 nanoseconds\n\njulia> time_from_index(1, 2)\n1000000000 nanoseconds\n\njulia> time_from_index(100, 100)\n990000000 nanoseconds\n\njulia> time_from_index(100, 101)\n1000000000 nanoseconds\n\n\n\n\n\ntime_from_index(sample_rate, sample_range::AbstractUnitRange)\n\nReturn the TimeSpan corresponding to sample_range given sample_rate in Hz:\n\njulia> time_from_index(100, 1:100)\nTimeSpan(0 nanoseconds, 1000000000 nanoseconds)\n\njulia> time_from_index(100, 101:101)\nTimeSpan(1000000000 nanoseconds, 1000000001 nanoseconds)\n\njulia> time_from_index(100, 301:600)\nTimeSpan(3000000000 nanoseconds, 6000000000 nanoseconds)\n\n\n\n\n\n","category":"function"},{"location":"#Onda.index_from_time","page":"API Documentation","title":"Onda.index_from_time","text":"index_from_time(sample_rate, sample_time)\n\nGiven sample_rate in Hz, return the integer index of the most recent sample taken at sample_time. Note that sample_time must be non-negative and support convert(Nanosecond, sample_time).\n\nExamples:\n\njulia> index_from_time(1, Second(0))\n1\n\njulia> index_from_time(1, Second(1))\n2\n\njulia> index_from_time(100, Millisecond(999))\n100\n\njulia> index_from_time(100, Millisecond(1000))\n101\n\n\n\n\n\nindex_from_time(sample_rate, span::AbstractTimeSpan)\n\nReturn the UnitRange of indices corresponding to span given sample_rate in Hz:\n\njulia> index_from_time(100, TimeSpan(Second(0), Second(1)))\n1:100\n\njulia> index_from_time(100, TimeSpan(Second(1)))\n101:101\n\njulia> index_from_time(100, TimeSpan(Second(3), Second(6)))\n301:600\n\n\n\n\n\n","category":"function"},{"location":"#Paths-API-1","page":"API Documentation","title":"Paths API","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda's Paths API directly underlies its Dataset API, providing an abstraction layer that can be overloaded to support new storage backends for sample data and recording metadata. This API's fallback implementation supports any path-like type P that supports:","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Base.read(::P)\nBase.write(::P, bytes::Vector{UInt8})\nBase.rm(::P; force, recursive)\nBase.joinpath(::P, ::AbstractString...)\nBase.mkpath(::P) (note: this is allowed to be a no-op for storage backends which have no notion of intermediate directories, e.g. object storage systems)\nBase.dirname(::P)\nOnda.read_byte_range (see signatures documented below)","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"read_recordings_file\nwrite_recordings_file\nsamples_path\nread_samples\nwrite_samples\nread_byte_range","category":"page"},{"location":"#Onda.read_recordings_file","page":"API Documentation","title":"Onda.read_recordings_file","text":"read_recordings_file(path)\n\nReturn deserialize_recordings_msgpack_zst(read(path)).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.write_recordings_file","page":"API Documentation","title":"Onda.write_recordings_file","text":"write_recordings_file(path, header::Header, recordings::Dict{UUID,Recording})\n\nWrite serialize_recordings_msgpack_zst(header, recordings) to path.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.samples_path","page":"API Documentation","title":"Onda.samples_path","text":"samples_path(dataset_path, uuid::UUID)\n\nReturn the path to the samples subdirectory within dataset_path corresponding to the recording specified by uuid.\n\n\n\n\n\nsamples_path(dataset_path, uuid::UUID, signal_name, file_extension)\n\nReturn the path to the sample data within dataset_path corresponding to the given signal information and the recording specified by uuid.\n\n\n\n\n\nsamples_path(dataset::Dataset, uuid::UUID)\n\nReturn samples_path(dataset.path, uuid).\n\n\n\n\n\nsamples_path(dataset::Dataset, uuid::UUID, signal_name::Symbol)\n\nReturn samples_path(dataset.path, uuid, signal_name, extension) where extension is defined as dataset.recordings[uuid].signals[signal_name].file_extension.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.read_samples","page":"API Documentation","title":"Onda.read_samples","text":"read_samples(path, signal::Signal)\n\nReturn the Samples object described by signal and stored at path.\n\n\n\n\n\nread_samples(path, signal::Signal, span::AbstractTimeSpan)\n\nReturn read_samples(path, signal)[:, span], but attempt to avoid reading unreturned intermediate sample data. Note that the effectiveness of this method depends on the types of both path and format(signal).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.write_samples","page":"API Documentation","title":"Onda.write_samples","text":"write_samples(path, samples::Samples)\n\nSerialize and write encode(samples) to path.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.read_byte_range","page":"API Documentation","title":"Onda.read_byte_range","text":"read_byte_range(path, byte_offset, byte_count)\n\nReturn the equivalent read(path)[(byte_offset + 1):(byte_offset + byte_count)], but try to avoid reading unreturned intermediate bytes. Note that the effectiveness of this method depends on the type of path.\n\n\n\n\n\n","category":"function"},{"location":"#Serialization-API-1","page":"API Documentation","title":"Serialization API","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda's Serialization API underlies its Paths API, providing a storage-agnostic abstraction layer that can be overloaded to support new file/byte formats for (de)serializing LPCM-encodeable sample data. This API also facilitates low-level streaming sample data (de)serialization and Onda metadata (de)serialization.","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"deserialize_recordings_msgpack_zst\nserialize_recordings_msgpack_zst\nAbstractLPCMFormat\nAbstractLPCMStream\ndeserializing_lpcm_stream\nserializing_lpcm_stream\nfinalize_lpcm_stream\nOnda.format_constructor_for_file_extension\nformat\ndeserialize_lpcm\ndeserialize_lpcm_callback\nserialize_lpcm\nLPCM\nLPCMZst","category":"page"},{"location":"#Onda.deserialize_recordings_msgpack_zst","page":"API Documentation","title":"Onda.deserialize_recordings_msgpack_zst","text":"deserialize_recordings_msgpack_zst(bytes::Vector{UInt8})\n\nReturn the (header::Header, recordings::Dict{UUID,Recording}) yielded from deserializing bytes, which is assumed to be in zstd-compressed MsgPack format and comply with the Onda format's specification of the contents of recordings.msgpack.zst.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.serialize_recordings_msgpack_zst","page":"API Documentation","title":"Onda.serialize_recordings_msgpack_zst","text":"serialize_recordings_msgpack_zst(header::Header, recordings::Dict{UUID,Recording})\n\nReturn the Vector{UInt8} that results from serializing (header::Header, recordings::Dict{UUID,Recording}) to zstd-compressed MsgPack format.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.AbstractLPCMFormat","page":"API Documentation","title":"Onda.AbstractLPCMFormat","text":"AbstractLPCMFormat\n\nA type whose subtypes represents byte/stream formats that can be (de)serialized to/from Onda's standard interleaved LPCM representation.\n\nAll subtypes of the form F<:AbstractLPCMFormat must support a constructor of the form F(::Signal) and overload Onda.format_constructor_for_file_extension with the appropriate file extension.\n\nSee also:\n\nformat\ndeserialize_lpcm\ndeserialize_lpcm_callback\nserialize_lpcm\nLPCM\nLPCMZst\nAbstractLPCMStream\n\n\n\n\n\n","category":"type"},{"location":"#Onda.AbstractLPCMStream","page":"API Documentation","title":"Onda.AbstractLPCMStream","text":"AbstractLPCMStream\n\nA type that represents an LPCM (de)serialization stream.\n\nSee also:\n\ndeserializing_lpcm_stream\nserializing_lpcm_stream\nfinalize_lpcm_stream\n\n\n\n\n\n","category":"type"},{"location":"#Onda.deserializing_lpcm_stream","page":"API Documentation","title":"Onda.deserializing_lpcm_stream","text":"deserializing_lpcm_stream(format::AbstractLPCMFormat, io)\n\nReturn a stream::AbstractLPCMStream that wraps io to enable direct LPCM deserialization from io via deserialize_lpcm.\n\nNote that stream must be finalized after usage via finalize_lpcm_stream. Until stream is finalized, io should be considered to be part of the internal state of stream and should not be directly interacted with by other processes.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.serializing_lpcm_stream","page":"API Documentation","title":"Onda.serializing_lpcm_stream","text":"serializing_lpcm_stream(format::AbstractLPCMFormat, io)\n\nReturn a stream::AbstractLPCMStream that wraps io to enable direct LPCM serialization to io via serialize_lpcm.\n\nNote that stream must be finalized after usage via finalize_lpcm_stream. Until stream is finalized, io should be considered to be part of the internal state of stream and should not be directly interacted with by other processes.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.finalize_lpcm_stream","page":"API Documentation","title":"Onda.finalize_lpcm_stream","text":"finalize_lpcm_stream(stream::AbstractLPCMStream)::Bool\n\nFinalize stream, returning true if the underlying I/O object used to construct stream is still open and usable. Otherwise, return false to indicate that underlying I/O object was closed as result of finalization.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.format_constructor_for_file_extension","page":"API Documentation","title":"Onda.format_constructor_for_file_extension","text":"Onda.format_constructor_for_file_extension(::Val{:extension_symbol})\n\nReturn a constructor of the form F(::Signal)::AbstractLPCMFormat corresponding to the provided extension.\n\nThis function should be overloaded for new AbstractLPCMFormat subtypes.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.format","page":"API Documentation","title":"Onda.format","text":"format(signal::Signal; kwargs...)\n\nReturn F(signal; kwargs...) where F is the AbstractLPCMFormat that corresponds to signal.file_extension (as determined by the format author via format_constructor_for_file_extension).\n\nSee also: deserialize_lpcm, serialize_lpcm\n\n\n\n\n\n","category":"function"},{"location":"#Onda.deserialize_lpcm","page":"API Documentation","title":"Onda.deserialize_lpcm","text":"deserialize_lpcm(format::AbstractLPCMFormat, bytes,\n                 samples_offset::Integer=0,\n                 samples_count::Integer=typemax(Int))\ndeserialize_lpcm(stream::AbstractLPCMStream,\n                 samples_offset::Integer=0,\n                 samples_count::Integer=typemax(Int))\n\nReturn a channels-by-timesteps AbstractMatrix of interleaved LPCM-encoded sample data by deserializing the provided bytes in the given format, or from the given stream constructed by deserializing_lpcm_stream.\n\nNote that this operation may be performed in a zero-copy manner such that the returned sample matrix directly aliases bytes.\n\nThe returned segment is at most sample_offset samples offset from the start of stream/bytes and contains at most sample_count samples. This ensures that overrun behavior is generally similar to the behavior of Base.skip(io, n) and Base.read(io, n).\n\nThis function is the inverse of the corresponding serialize_lpcm method, i.e.:\n\nserialize_lpcm(format, deserialize_lpcm(format, bytes)) == bytes\n\n\n\n\n\n","category":"function"},{"location":"#Onda.deserialize_lpcm_callback","page":"API Documentation","title":"Onda.deserialize_lpcm_callback","text":"deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)\n\nReturn (callback, required_byte_offset, required_byte_count) where callback accepts the byte block specified by required_byte_offset and required_byte_count and returns the samples specified by samples_offset and samples_count.\n\nAs a fallback, this function returns (callback, missing, missing), where callback requires all available bytes. AbstractLPCMFormat subtypes that support partial/block-based deserialization (e.g. the basic LPCM format) can overload this function to only request exactly the byte range that is required for the sample range requested by the caller.\n\nThis allows callers to handle the byte block retrieval themselves while keeping Onda's LPCM Serialization API agnostic to the caller's storage layer of choice.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.serialize_lpcm","page":"API Documentation","title":"Onda.serialize_lpcm","text":"serialize_lpcm(format::AbstractLPCMFormat, samples::AbstractMatrix)\nserialize_lpcm(stream::AbstractLPCMStream, samples::AbstractMatrix)\n\nReturn the AbstractVector{UInt8} of bytes that results from serializing samples to the given format (or serialize those bytes directly to stream) where samples is a channels-by-timesteps matrix of interleaved LPCM-encoded sample data.\n\nNote that this operation may be performed in a zero-copy manner such that the returned AbstractVector{UInt8} directly aliases samples.\n\nThis function is the inverse of the corresponding deserialize_lpcm method, i.e.:\n\ndeserialize_lpcm(format, serialize_lpcm(format, samples)) == samples\n\n\n\n\n\n","category":"function"},{"location":"#Onda.LPCM","page":"API Documentation","title":"Onda.LPCM","text":"LPCM{S}(channel_count)\nLPCM(signal::Signal)\n\nReturn a LPCM<:AbstractLPCMFormat instance corresponding to Onda's default interleaved LPCM format assumed for sample data files with the \"lpcm\" extension.\n\nS corresponds to signal.sample_type, while channel_count corresponds to length(signal.channel_names).\n\nNote that bytes (de)serialized to/from this format are little-endian (per the Onda specification).\n\n\n\n\n\n","category":"type"},{"location":"#Onda.LPCMZst","page":"API Documentation","title":"Onda.LPCMZst","text":"LPCMZst(lpcm::LPCM; level=3)\nLPCMZst(signal::Signal; level=3)\n\nReturn a LPCMZst<:AbstractLPCMFormat instance that corresponds to Onda's default interleaved LPCM format compressed by zstd. This format is assumed for sample data files with the \"lpcm.zst\" extension.\n\nThe level keyword argument sets the same compression level parameter as the corresponding flag documented by the zstd command line utility.\n\nSee https://facebook.github.io/zstd/ for details about zstd.\n\n\n\n\n\n","category":"type"},{"location":"#Upgrading-Older-Datasets-to-Newer-Datasets-1","page":"API Documentation","title":"Upgrading Older Datasets to Newer Datasets","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda.upgrade_onda_format_from_v0_2_to_v0_3!","category":"page"},{"location":"#Onda.upgrade_onda_format_from_v0_2_to_v0_3!","page":"API Documentation","title":"Onda.upgrade_onda_format_from_v0_2_to_v0_3!","text":"Onda.upgrade_onda_format_from_v0_2_to_v0_3!(path, combine_annotation_key_value)\n\nUpgrade the Onda v0.2 dataset at path to a Onda v0.3 dataset, returning the upgraded Dataset. This upgrade process overwrites path/recordings.msgpack.zst with a v0.3-compliant version of this file; for safety's sake, the old v0.2 file is preserved at path/old.recordings.msgpack.zst.backup.\n\nA couple of the Onda v0.2 -> v0.3 changes require some special handling:\n\nThe custom field was removed from recording objects. This function thus writes out a file at path/recordings_custom.msgpack.zst that contains a map of UUIDs to corresponding recordings' custom values before deleting the custom field. This file can be deserialized via MsgPack.unpack(Onda.zstd_decompress(read(\"recordings_custom.msgpack.zst\"))).\nAnnotations no longer have a key field. Thus, each annotation's existing key and value fields are combined into the single new value field via the provided callback combine_annotation_key_value(annotation_key, annotation_value).\n\n\n\n\n\n","category":"function"}]
}
