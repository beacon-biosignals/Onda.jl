var documenterSearchIndex = {"docs":
[{"location":"upgrading/#Upgrading-From-Older-Versions-Of-Onda-1","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"","category":"section"},{"location":"upgrading/#To-v0.14-From-v0.13-1","page":"Upgrading From Older Versions Of Onda","title":"To v0.14 From v0.13","text":"","category":"section"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"Potentially breaking changes include:","category":"page"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"SamplesInfo's sample_type field is now an AbstractString (see sample_type in https://github.com/beacon-biosignals/Onda.jl#columns) as opposed to a DataType. The sample_type function should now be used to retrieve this field as a DataType.\nSince SampleInfo/Signal/Annotation are now Legolas.Row aliases, any instance of these types may contain additional author-provided fields atop required fields. Thus, code that relies on these types containing a specific number of fields (or similarly, a specific field order) might break in generic usage.","category":"page"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"Otherwise, there are no intended breaking changes from v0.13 to v0.14 that do not have a supported deprecation path. These deprecation paths will be maintained for at least one 0.x release cycle. To upgrade your code, simply run your code/tests with Julia's --depwarn=yes flag enabled and make the updates recommended by whatever deprecation warnings arise.","category":"page"},{"location":"upgrading/#To-v0.14-From-v0.11-Or-Older-1","page":"Upgrading From Older Versions Of Onda","title":"To v0.14 From v0.11 Or Older","text":"","category":"section"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"Before Onda.jl v0.12, signal and annotation metadata was stored (both in-memory, and serialized) in a nested Dict-like structure wrapped by the Onda.Dataset type. In the Onda.jl v0.12 release, we dropped the Onda.Dataset type and instead switched to storing signal and annotation metadata in separate Arrow tables. See here for the motivations behind this switch.","category":"page"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"Tips for upgrading:","category":"page"},{"location":"upgrading/#","page":"Upgrading From Older Versions Of Onda","title":"Upgrading From Older Versions Of Onda","text":"Onda.jl v0.13 contains a convenience function, Onda.upgrade_onda_dataset_to_v0_5!, to automatically upgrade old datasets to the new format. This function has since been removed after several deprecation cycles, but it can still be invoked as needed by Pkg.adding/Pkg.pining Onda at version=\"0.13\". See the function's docstring for more details.\nThe newer tabular format enables consumers/producers to easily impose whatever indexing structure is most convenient for their use case, including the old format's indexing structure. This can be useful for upgrading old code that utilized the old Onda.Recording/Onda.Dataset types. Specifically, the Onda Tour shows how tables in the new format can indexed in the same manner as the old format via a few simple commands. This tour is highly recommended for authors that are upgrading old code, as it directly demonstrates how to perform many common Onda operations (e.g. sample data storing/loading) using the latest version of the package.\nThe following changes were made to Onda.Signal:\nFormerly, each signal was stored as the pair kind::Symbol => metadata within a dictionary keyed to a specific recording::UUID. Now that each signal is a self-contained table row, each signal contains its own recording::UUID and kind::String fields. Note that, unlike the old format, the new data model allows the existence of multiple signals of the same kind in the same recording (see here for guidance on the interpretation of such data). If a primary key is needed to identify individual sample data artifacts, use the file_path field instead of the kind field.\nThe file_extension/file_options fields were replaced by the file_path/file_format fields.\nThe channel_names::Vector{Symbol} field was changed to channels::Vector{String}.\nThe start_nanosecond/stop_nanosecond fields were replaced with a single span::TimeSpan field.\nThe sample_unit::Symbol field was changed to sample_unit::String.\nThe following changes were made to Onda.Annotation:\nFormerly, annotations were stored as a simple list keyed to a specific recording::UUID. Now that each annotation is a self-contained table row, each annotation contains its own recording::UUID and id::UUID fields. The latter field serves as a primary key to identify individual annotations.\nThe start_nanosecond/stop_nanosecond fields were replaced with a single span::TimeSpan field.\nThe value field was dropped in favor of allowing annotation authors to provide arbitrary custom columns tailored to their use case.","category":"page"},{"location":"#API-Documentation-1","page":"API Documentation","title":"API Documentation","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"We highly recommend that newcomers walk through the Onda Tour before diving into this reference documentation.","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"CurrentModule = Onda","category":"page"},{"location":"#Support-For-Generic-Path-Like-Types-1","page":"API Documentation","title":"Support For Generic Path-Like Types","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda.jl attempts to be as agnostic as possible with respect to the storage system that sample data, Arrow files, etc. are read from/written to. As such, any path-like argument accepted by an Onda.jl API function should generically \"work\" as long as the argument's type supports:","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Base.read(path)::Vector{UInt8} (return the bytes stored at path)\nBase.write(path, bytes::Vector{UInt8}) (write bytes to the location specified by path)","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"For backends which support direct byte range access (e.g. S3), Onda.read_byte_range may be overloaded for the backend's corresponding path type to enable further optimizations:","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda.read_byte_range","category":"page"},{"location":"#Onda.read_byte_range","page":"API Documentation","title":"Onda.read_byte_range","text":"read_byte_range(path, byte_offset, byte_count)\n\nReturn the equivalent read(path)[(byte_offset + 1):(byte_offset + byte_count)], but try to avoid reading unreturned intermediate bytes. Note that the effectiveness of this method depends on the type of path.\n\n\n\n\n\n","category":"function"},{"location":"#onda.annotation-1","page":"API Documentation","title":"onda.annotation","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Annotation\nwrite_annotations\nvalidate_annotations\nmerge_overlapping_annotations","category":"page"},{"location":"#Onda.Annotation","page":"API Documentation","title":"Onda.Annotation","text":"const Annotation = Legolas.@row(\"onda.annotation@1\",\n                                recording::UUID,\n                                id::UUID,\n                                span::TimeSpan)\n\nA type alias for Legolas.Row{typeof(Legolas.Schema(\"onda.annotation@1\"))} representing an onda.annotation as described by the Onda Format Specification.\n\nThis type primarily exists to aid in the validated row construction, and is not intended to be used as a type constraint in function or struct definitions. Instead, you should generally duck-type any \"annotation-like\" arguments/fields so that other generic row types will compose with your code.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.write_annotations","page":"API Documentation","title":"Onda.write_annotations","text":"write_annotations(io_or_path, table; kwargs...)\n\nInvoke/return Legolas.write(path_or_io, annotations, Schema(\"onda.annotation@1\"); kwargs...).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.validate_annotations","page":"API Documentation","title":"Onda.validate_annotations","text":"validate_annotations(annotations)\n\nPerform both table-level and row-level validation checks on the content of annotations, a presumed onda.annotation table. Returns annotations.\n\nThis function will throw an error in any of the following cases:\n\nLegolas.validate(annotations, Legolas.Schema(\"onda.annotation@1\")) throws an error\nAnnotation(row) errors for any row in Tables.rows(annotations)\nannotations contains rows with duplicate ids\n\n\n\n\n\n","category":"function"},{"location":"#Onda.merge_overlapping_annotations","page":"API Documentation","title":"Onda.merge_overlapping_annotations","text":"merge_overlapping_annotations([predicate=TimeSpans.overlaps,] annotations)\n\nGiven the onda.annotation-compliant table annotations, return a table corresponding to annotations except that consecutive entries satisfying predicate have been merged using TimeSpans.shortest_timespan_containing. The predicate must be of the form prediate(next_span::TimeSpan, prev_span::TimeSpan)::Bool returning whether or not to merge the annotations corresponding to next_span and prev_span, where next_span is the next span in the same recording as prev_span.\n\nSpecifically, two annotations a and b are determined to be \"overlapping\" if a.recording == b.recording && predicate(a.span, b.span), where the default value of predicate is TimeSpans.overlaps. Merged annotations' span fields are generated via calling TimeSpans.shortest_timespan_containing on the overlapping set of source annotations.\n\nThe returned annotations table only has a single custom column named from whose entries are Vector{UUID}s populated with the ids of the generated annotations' source(s). Note that every annotation in the returned table has a freshly generated id field and a non-empty from field, even if the from only has a single element (i.e. corresponds to a single non-overlapping annotation).\n\nNote that this function internally works with Tables.columns(annotations) rather than annotations directly, so it may be slower and/or require more memory if !Tables.columnaccess(annotations).\n\nSee also TimeSpans.merge_spans for similar functionality on timespans (instead of annotations).\n\n\n\n\n\n","category":"function"},{"location":"#onda.signal-1","page":"API Documentation","title":"onda.signal","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Signal\nSamplesInfo\nwrite_signals\nvalidate_signals\nchannel(x, name)\nchannel(x, i::Integer)\nchannel_count(x)\nsample_count(x, duration::Period)\nsizeof_samples(x, duration::Period)\nsample_type(x)","category":"page"},{"location":"#Onda.Signal","page":"API Documentation","title":"Onda.Signal","text":"const Signal = @row(\"onda.signal@1\" > \"onda.samples-info@1\",\n                    recording::UUID,\n                    file_path::Any,\n                    file_format::String = (file_format isa AbstractLPCMFormat ?\n                                           Onda.file_format_string(file_format) :\n                                           file_format),\n                    span::TimeSpan)\n\nA type alias for Legolas.Row{typeof(Legolas.Schema(\"onda.signal@1\"))} representing an onda.signal as described by the Onda Format Specification.\n\nNote that the Signal constructor will perform additional validation on underlying onda.samples-info@1 fields to  ensure that these fields are compliant with the Onda specification; an ArgumentError will be thrown if any fields  are invalid.\n\nThis type primarily exists to aid in the validated row construction, and is not intended to be used as a type constraint  in function or struct definitions. Instead, you should generally duck-type any \"signal-like\" arguments/fields so that  other generic row types will compose with your code.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.SamplesInfo","page":"API Documentation","title":"Onda.SamplesInfo","text":"const SamplesInfo = @row(\"onda.samples-info@1\",\n                         kind::String,\n                         channels::Vector{String},\n                         sample_unit::String,\n                         sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION,\n                         sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION,\n                         sample_type::String = Onda.onda_sample_type_from_julia_type(sample_type),\n                         sample_rate::LPCM_SAMPLE_TYPE_UNION)\n\nA type alias for Legolas.Row{typeof(Legolas.Schema(\"onda.samples-info@1\"))} representing the bundle of onda.signal fields that are intrinsic to a signal's sample data, leaving out extrinsic file or recording information. This is useful when the latter information is irrelevant or does not yet exist (e.g. if sample data is being constructed/manipulated in-memory without yet having been serialized).\n\n\n\n\n\n","category":"type"},{"location":"#Onda.write_signals","page":"API Documentation","title":"Onda.write_signals","text":"write_signals(io_or_path, table; kwargs...)\n\nInvoke/return Legolas.write(path_or_io, signals, Schema(\"onda.signal@1\"); kwargs...).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.validate_signals","page":"API Documentation","title":"Onda.validate_signals","text":"validate_signals(signals)\n\nPerform both table-level and row-level validation checks on the content of signals, a presumed onda.signal table. Returns signals.\n\nThis function will throw an error in any of the following cases:\n\nLegolas.validate(signals, Legolas.Schema(\"onda.signal@1\")) throws an error\nSignal(row) errors for any row in Tables.rows(signals)\nsignals contains rows with duplicate file_paths\n\n\n\n\n\n","category":"function"},{"location":"#Onda.channel-Tuple{Any, Any}","page":"API Documentation","title":"Onda.channel","text":"channel(x, name)\n\nReturn i where x.channels[i] == name.\n\n\n\n\n\n","category":"method"},{"location":"#Onda.channel-Tuple{Any, Integer}","page":"API Documentation","title":"Onda.channel","text":"channel(x, i::Integer)\n\nReturn x.channels[i].\n\n\n\n\n\n","category":"method"},{"location":"#Onda.channel_count-Tuple{Any}","page":"API Documentation","title":"Onda.channel_count","text":"channel_count(x)\n\nReturn length(x.channels).\n\n\n\n\n\n","category":"method"},{"location":"#Onda.sample_count-Tuple{Any, Dates.Period}","page":"API Documentation","title":"Onda.sample_count","text":"sample_count(x, duration::Period)\n\nReturn the number of multichannel samples that fit within duration given x.sample_rate.\n\n\n\n\n\n","category":"method"},{"location":"#Onda.sizeof_samples-Tuple{Any, Dates.Period}","page":"API Documentation","title":"Onda.sizeof_samples","text":"sizeof_samples(x, duration::Period)\n\nReturns the expected size (in bytes) of an encoded Samples object corresponding to x and duration:\n\nsample_count(x, duration) * channel_count(x) * sizeof(x.sample_type)\n\n\n\n\n\n","category":"method"},{"location":"#Onda.sample_type-Tuple{Any}","page":"API Documentation","title":"Onda.sample_type","text":"sample_type(x)\n\nReturn x.sample_type as an Onda.LPCM_SAMPLE_TYPE_UNION subtype. If x.sample_type is an Onda-specified sample_type string (e.g. \"int16\"), it will be converted to the corresponding Julia type. If x.sample_type <: Onda.LPCM_SAMPLE_TYPE_UNION, this function simply returns x.sample_type as-is.\n\n\n\n\n\n","category":"method"},{"location":"#Samples-1","page":"API Documentation","title":"Samples","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Samples\n==(::Samples, ::Samples)\nchannel\nchannel_count\nsample_count\nencode\nencode!\ndecode\ndecode!\nload\nOnda.mmap\nstore\nchannel(samples::Samples, name)\nchannel(samples::Samples, i::Integer)\nchannel_count(samples::Samples)\nsample_count(samples::Samples)","category":"page"},{"location":"#Onda.Samples","page":"API Documentation","title":"Onda.Samples","text":"Samples(data::AbstractMatrix, info::SamplesInfo, encoded::Bool;\n        validate::Bool=Onda.VALIDATE_SAMPLES_DEFAULT[])\n\nReturn a Samples instance with the following fields:\n\ndata::AbstractMatrix: A matrix of sample data. The i th row of the matrix corresponds to the ith channel in info.channels, while the jth column corresponds to the jth multichannel sample.\ninfo::SamplesInfo: The SamplesInfo object that describes the Samples instance.\nencoded::Bool: If true, the values in data are LPCM-encoded as prescribed by the Samples instance's info. If false, the values in data have been decoded into the info's canonical units.\n\nIf validate is true, Onda.validate is called on the constructed Samples instance before it is returned.\n\nNote that getindex and view are defined on Samples to accept normal integer indices, but also accept channel names or a regex to match channel names for row indices, and TimeSpan values for column indices; see Onda/examples/tour.jl for a comprehensive set of indexing examples.\n\nSee also: load, store, encode, encode!, decode, decode!\n\n\n\n\n\n","category":"type"},{"location":"#Base.:==-Tuple{Samples, Samples}","page":"API Documentation","title":"Base.:==","text":"==(a::Samples, b::Samples)\n\nReturns a.encoded == b.encoded && a.info == b.info && a.data == b.data.\n\n\n\n\n\n","category":"method"},{"location":"#Onda.channel","page":"API Documentation","title":"Onda.channel","text":"channel(x, name)\n\nReturn i where x.channels[i] == name.\n\n\n\n\n\nchannel(x, i::Integer)\n\nReturn x.channels[i].\n\n\n\n\n\nchannel(samples::Samples, name)\n\nReturn channel(samples.info, name).\n\nThis function is useful for indexing rows of samples.data by channel names.\n\n\n\n\n\nchannel(samples::Samples, i::Integer)\n\nReturn channel(samples.info, i).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.channel_count","page":"API Documentation","title":"Onda.channel_count","text":"channel_count(x)\n\nReturn length(x.channels).\n\n\n\n\n\nchannel_count(samples::Samples)\n\nReturn channel_count(samples.info).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.sample_count","page":"API Documentation","title":"Onda.sample_count","text":"sample_count(x, duration::Period)\n\nReturn the number of multichannel samples that fit within duration given x.sample_rate.\n\n\n\n\n\nsample_count(samples::Samples)\n\nReturn the number of multichannel samples in samples (i.e. size(samples.data, 2))\n\n\n\n\n\n","category":"function"},{"location":"#Onda.encode","page":"API Documentation","title":"Onda.encode","text":"encode(sample_type::DataType, sample_resolution_in_unit, sample_offset_in_unit,\n       sample_data, dither_storage=nothing)\n\nReturn a copy of sample_data quantized according to sample_type, sample_resolution_in_unit, and sample_offset_in_unit. sample_type must be a concrete subtype of Onda.LPCM_SAMPLE_TYPE_UNION. Quantization of an individual sample s is performed via:\n\nround(S, (s - sample_offset_in_unit) / sample_resolution_in_unit)\n\nwith additional special casing to clip values exceeding the encoding's dynamic range.\n\nIf dither_storage isa Nothing, no dithering is applied before quantization.\n\nIf dither_storage isa Missing, dither storage is allocated automatically and triangular dithering is applied to the info prior to quantization.\n\nOtherwise, dither_storage must be a container of similar shape and type to sample_data. This container is then used to store the random noise needed for the triangular dithering process, which is applied to the info prior to quantization.\n\nIf:\n\nsample_type === eltype(sample_data) &&\nsample_resolution_in_unit == 1 &&\nsample_offset_in_unit == 0\n\nthen this function will simply return sample_data directly without copying/dithering.\n\n\n\n\n\nencode(samples::Samples, dither_storage=nothing)\n\nIf samples.encoded is false, return a Samples instance that wraps:\n\nencode(sample_type(samples.info),\n       samples.info.sample_resolution_in_unit,\n       samples.info.sample_offset_in_unit,\n       samples.data, dither_storage)\n\nIf samples.encoded is true, this function is the identity.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.encode!","page":"API Documentation","title":"Onda.encode!","text":"encode!(result_storage, sample_type::DataType, sample_resolution_in_unit,\n        sample_offset_in_unit, sample_data, dither_storage=nothing)\nencode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit,\n        sample_data, dither_storage=nothing)\n\nSimilar to encode(sample_type, sample_resolution_in_unit, sample_offset_in_unit, sample_data, dither_storage), but write encoded values to result_storage rather than allocating new storage.\n\nsample_type defaults to eltype(result_storage) if it is not provided.\n\nIf:\n\nsample_type === eltype(sample_data) &&\nsample_resolution_in_unit == 1 &&\nsample_offset_in_unit == 0\n\nthen this function will simply copy sample_data directly into result_storage without dithering.\n\n\n\n\n\nencode!(result_storage, samples::Samples, dither_storage=nothing)\n\nIf samples.encoded is false, return a Samples instance that wraps:\n\nencode!(result_storage,\n        sample_type(samples.info),\n        samples.info.sample_resolution_in_unit,\n        samples.info.sample_offset_in_unit,\n        samples.data, dither_storage)`.\n\nIf samples.encoded is true, return a Samples instance that wraps copyto!(result_storage, samples.data).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.decode","page":"API Documentation","title":"Onda.decode","text":"decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data)\n\nReturn sample_resolution_in_unit .* sample_data .+ sample_offset_in_unit.\n\nIf:\n\nsample_data isa AbstractArray &&\nsample_resolution_in_unit == 1 &&\nsample_offset_in_unit == 0\n\nthen this function is the identity and will return sample_data directly without copying.\n\n\n\n\n\ndecode(samples::Samples)\n\nIf samples.encoded is true, return a Samples instance that wraps\n\ndecode(samples.info.sample_resolution_in_unit, samples.info.sample_offset_in_unit, samples.data)\n\nIf samples.encoded is false, this function is the identity.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.decode!","page":"API Documentation","title":"Onda.decode!","text":"decode!(result_storage, sample_resolution_in_unit, sample_offset_in_unit, sample_data)\n\nSimilar to decode(sample_resolution_in_unit, sample_offset_in_unit, sample_data), but write decoded values to result_storage rather than allocating new storage.\n\n\n\n\n\ndecode!(result_storage, samples::Samples)\n\nIf samples.encoded is true, return a Samples instance that wraps\n\ndecode!(result_storage, samples.info.sample_resolution_in_unit, samples.info.sample_offset_in_unit, samples.data)\n\nIf samples.encoded is false, return a Samples instance that wraps copyto!(result_storage, samples.data).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.load","page":"API Documentation","title":"Onda.load","text":"load(signal[, span_relative_to_loaded_samples]; encoded::Bool=false)\nload(file_path, file_format::Union{AbstractString,AbstractLPCMFormat},\n     info::SamplesInfo[, span_relative_to_loaded_samples]; encoded::Bool=false)\n\nReturn the Samples object described by signal/file_path/file_format/info.\n\nIf span_relative_to_loaded_samples is present, return load(...)[:, span_relative_to_loaded_samples], but attempt to avoid reading unreturned intermediate sample data. Note that the effectiveness of this optimized method versus the naive approach depends on the types of file_path (i.e. if there is a fast method defined for Onda.read_byte_range(::typeof(file_path), ...)) and file_format (i.e. does the corresponding format support random or chunked access).\n\nIf encoded is true, do not decode the Samples object before returning it.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.mmap","page":"API Documentation","title":"Onda.mmap","text":"Onda.mmap(signal)\n\nReturn Onda.mmap(signal.file_path, Onda.extract_samples_info(signal)), throwing an ArgumentError if signal.file_format != \"lpcm\".\n\n\n\n\n\nOnda.mmap(mmappable, info::SamplesInfo)\n\nReturn Samples(data, info, true) where data is created via Mmap.mmap(mmappable, ...).\n\nmmappable is assumed to reference memory that is formatted according to the Onda Format's canonical interleaved LPCM representation in accordance with sample_type(info) and channel_count(info). No explicit checks are performed to ensure that this is true.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.store","page":"API Documentation","title":"Onda.store","text":"store(file_path, file_format::Union{AbstractString,AbstractLPCMFormat}, samples::Samples)\n\nSerialize the given samples to file_format and write the output to file_path.\n\n\n\n\n\nstore(file_path, file_format::Union{AbstractString,AbstractLPCMFormat}, samples::Samples,\n      recording::UUID, start::Period; custom...)\n\nSerialize the given samples to file_format and write the output to file_path, returning a Signal instance constructed from the provided arguments (any provided custom keyword arguments are forwarded to an invocation of the Signal constructor).\n\n\n\n\n\n","category":"function"},{"location":"#Onda.channel-Tuple{Samples, Any}","page":"API Documentation","title":"Onda.channel","text":"channel(samples::Samples, name)\n\nReturn channel(samples.info, name).\n\nThis function is useful for indexing rows of samples.data by channel names.\n\n\n\n\n\n","category":"method"},{"location":"#Onda.channel-Tuple{Samples, Integer}","page":"API Documentation","title":"Onda.channel","text":"channel(samples::Samples, i::Integer)\n\nReturn channel(samples.info, i).\n\n\n\n\n\n","category":"method"},{"location":"#Onda.channel_count-Tuple{Samples}","page":"API Documentation","title":"Onda.channel_count","text":"channel_count(samples::Samples)\n\nReturn channel_count(samples.info).\n\n\n\n\n\n","category":"method"},{"location":"#Onda.sample_count-Tuple{Samples}","page":"API Documentation","title":"Onda.sample_count","text":"sample_count(samples::Samples)\n\nReturn the number of multichannel samples in samples (i.e. size(samples.data, 2))\n\n\n\n\n\n","category":"method"},{"location":"#LPCM-(De)serialization-API-1","page":"API Documentation","title":"LPCM (De)serialization API","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"Onda.jl's LPCM (De)serialization API facilitates low-level streaming sample data (de)serialization and provides a storage-agnostic abstraction layer that can be overloaded to support new file/byte formats for (de)serializing LPCM-encodeable sample data.","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"AbstractLPCMFormat\nAbstractLPCMStream\nLPCMFormat\nLPCMZstFormat\nformat\ndeserialize_lpcm\nserialize_lpcm\ndeserialize_lpcm_callback\ndeserializing_lpcm_stream\nserializing_lpcm_stream\nfinalize_lpcm_stream\nOnda.register_lpcm_format!\nOnda.file_format_string","category":"page"},{"location":"#Onda.AbstractLPCMFormat","page":"API Documentation","title":"Onda.AbstractLPCMFormat","text":"AbstractLPCMFormat\n\nA type whose subtypes represents byte/stream formats that can be (de)serialized to/from Onda's standard interleaved LPCM representation.\n\nAll subtypes of the form F<:AbstractLPCMFormat must call Onda.register_lpcm_format! and define an appropriate file_format_string method.\n\nSee also:\n\nformat\ndeserialize_lpcm\ndeserialize_lpcm_callback\nserialize_lpcm\nLPCMFormat\nLPCMZstFormat\nAbstractLPCMStream\n\n\n\n\n\n","category":"type"},{"location":"#Onda.AbstractLPCMStream","page":"API Documentation","title":"Onda.AbstractLPCMStream","text":"AbstractLPCMStream\n\nA type that represents an LPCM (de)serialization stream.\n\nSee also:\n\ndeserializing_lpcm_stream\nserializing_lpcm_stream\nfinalize_lpcm_stream\n\n\n\n\n\n","category":"type"},{"location":"#Onda.LPCMFormat","page":"API Documentation","title":"Onda.LPCMFormat","text":"LPCMFormat(channel_count::Int, sample_type::Type)\nLPCMFormat(info::SamplesInfo)\n\nReturn a LPCMFormat<:AbstractLPCMFormat instance corresponding to Onda's default interleaved LPCM format assumed for sample data files with the \"lpcm\" extension.\n\nchannel_count corresponds to length(info.channels), while sample_type corresponds to sample_type(info)\n\nNote that bytes (de)serialized to/from this format are little-endian (per the Onda specification).\n\n\n\n\n\n","category":"type"},{"location":"#Onda.LPCMZstFormat","page":"API Documentation","title":"Onda.LPCMZstFormat","text":"LPCMZstFormat(lpcm::LPCMFormat; level=3)\nLPCMZstFormat(info::SamplesInfo; level=3)\n\nReturn a LPCMZstFormat<:AbstractLPCMFormat instance that corresponds to Onda's default interleaved LPCM format compressed by zstd. This format is assumed for sample data files with the \"lpcm.zst\" extension.\n\nThe level keyword argument sets the same compression level parameter as the corresponding flag documented by the zstd command line utility.\n\nSee https://facebook.github.io/zstd/ for details about zstd.\n\n\n\n\n\n","category":"type"},{"location":"#Onda.format","page":"API Documentation","title":"Onda.format","text":"format(file_format::AbstractString, info::SamplesInfo; kwargs...)\n\nReturn f(info; kwargs...) where f constructs the AbstractLPCMFormat instance that corresponds to file_format. f is determined by matching file_format to a suitable format constuctor registered via register_lpcm_format!.\n\nSee also: deserialize_lpcm, serialize_lpcm\n\n\n\n\n\n","category":"function"},{"location":"#Onda.deserialize_lpcm","page":"API Documentation","title":"Onda.deserialize_lpcm","text":"deserialize_lpcm(format::AbstractLPCMFormat, bytes,\n                 samples_offset::Integer=0,\n                 samples_count::Integer=typemax(Int))\ndeserialize_lpcm(stream::AbstractLPCMStream,\n                 samples_offset::Integer=0,\n                 samples_count::Integer=typemax(Int))\n\nReturn a channels-by-timesteps AbstractMatrix of interleaved LPCM-encoded sample data by deserializing the provided bytes in the given format, or from the given stream constructed by deserializing_lpcm_stream.\n\nNote that this operation may be performed in a zero-copy manner such that the returned sample matrix directly aliases bytes.\n\nThe returned segment is at most sample_offset samples offset from the start of stream/bytes and contains at most sample_count samples. This ensures that overrun behavior is generally similar to the behavior of Base.skip(io, n) and Base.read(io, n).\n\nThis function is the inverse of the corresponding serialize_lpcm method, i.e.:\n\nserialize_lpcm(format, deserialize_lpcm(format, bytes)) == bytes\n\n\n\n\n\n","category":"function"},{"location":"#Onda.serialize_lpcm","page":"API Documentation","title":"Onda.serialize_lpcm","text":"serialize_lpcm(format::AbstractLPCMFormat, samples::AbstractMatrix)\nserialize_lpcm(stream::AbstractLPCMStream, samples::AbstractMatrix)\n\nReturn the AbstractVector{UInt8} of bytes that results from serializing samples to the given format (or serialize those bytes directly to stream) where samples is a channels-by-timesteps matrix of interleaved LPCM-encoded sample data.\n\nNote that this operation may be performed in a zero-copy manner such that the returned AbstractVector{UInt8} directly aliases samples.\n\nThis function is the inverse of the corresponding deserialize_lpcm method, i.e.:\n\ndeserialize_lpcm(format, serialize_lpcm(format, samples)) == samples\n\n\n\n\n\n","category":"function"},{"location":"#Onda.deserialize_lpcm_callback","page":"API Documentation","title":"Onda.deserialize_lpcm_callback","text":"deserialize_lpcm_callback(format::AbstractLPCMFormat, samples_offset, samples_count)\n\nReturn (callback, required_byte_offset, required_byte_count) where callback accepts the byte block specified by required_byte_offset and required_byte_count and returns the samples specified by samples_offset and samples_count.\n\nAs a fallback, this function returns (callback, missing, missing), where callback requires all available bytes. AbstractLPCMFormat subtypes that support partial/block-based deserialization (e.g. the basic LPCMFormat) can overload this function to only request exactly the byte range that is required for the sample range requested by the caller.\n\nThis allows callers to handle the byte block retrieval themselves while keeping Onda's LPCM Serialization API agnostic to the caller's storage layer of choice.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.deserializing_lpcm_stream","page":"API Documentation","title":"Onda.deserializing_lpcm_stream","text":"deserializing_lpcm_stream(format::AbstractLPCMFormat, io)\n\nReturn a stream::AbstractLPCMStream that wraps io to enable direct LPCM deserialization from io via deserialize_lpcm.\n\nNote that stream must be finalized after usage via finalize_lpcm_stream. Until stream is finalized, io should be considered to be part of the internal state of stream and should not be directly interacted with by other processes.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.serializing_lpcm_stream","page":"API Documentation","title":"Onda.serializing_lpcm_stream","text":"serializing_lpcm_stream(format::AbstractLPCMFormat, io)\n\nReturn a stream::AbstractLPCMStream that wraps io to enable direct LPCM serialization to io via serialize_lpcm.\n\nNote that stream must be finalized after usage via finalize_lpcm_stream. Until stream is finalized, io should be considered to be part of the internal state of stream and should not be directly interacted with by other processes.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.finalize_lpcm_stream","page":"API Documentation","title":"Onda.finalize_lpcm_stream","text":"finalize_lpcm_stream(stream::AbstractLPCMStream)::Bool\n\nFinalize stream, returning true if the underlying I/O object used to construct stream is still open and usable. Otherwise, return false to indicate that underlying I/O object was closed as result of finalization.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.register_lpcm_format!","page":"API Documentation","title":"Onda.register_lpcm_format!","text":"Onda.register_lpcm_format!(create_constructor)\n\nRegister an AbstractLPCMFormat constructor so that it can automatically be used when format is called. Authors of new AbstractLPCMFormat subtypes should call this function for their subtype.\n\ncreate_constructor should be a unary function that accepts a single file_format::AbstractString argument, and return either a matching AbstractLPCMFormat constructor or nothing. Any returned AbstractLPCMFormat constructor f should be of the form f(info::SamplesInfo; kwargs...)::AbstractLPCMFormat.\n\nNote that if Onda.register_lpcm_format! is called in a downstream package, it must be called within the __init__ function of the package's top-level module to ensure that the function is always invoked when the module is loaded (not just during precompilation). For details, see https://docs.julialang.org/en/v1/manual/modules/#Module-initialization-and-precompilation.\n\n\n\n\n\n","category":"function"},{"location":"#Onda.file_format_string","page":"API Documentation","title":"Onda.file_format_string","text":"file_format_string(format::AbstractLPCMFormat)\n\nReturn the String representation of format to be written to the file_format field of a *.signals file.\n\n\n\n\n\n","category":"function"},{"location":"#Utilities-1","page":"API Documentation","title":"Utilities","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"VALIDATE_SAMPLES_DEFAULT","category":"page"},{"location":"#Onda.VALIDATE_SAMPLES_DEFAULT","page":"API Documentation","title":"Onda.VALIDATE_SAMPLES_DEFAULT","text":"VALIDATE_SAMPLES_DEFAULT[]\n\nDefaults to true.\n\nWhen set to true, Samples objects will be validated upon construction for compliance with the Onda specification.\n\nUsers may interactively set this reference to false in order to disable this extra layer validation, which can be useful when working with malformed Onda datasets.\n\nSee also: Onda.validate\n\n\n\n\n\n","category":"constant"},{"location":"#Developer-Installation-1","page":"API Documentation","title":"Developer Installation","text":"","category":"section"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"To install Onda for development, run:","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"julia -e 'using Pkg; Pkg.develop(\"Onda\")'","category":"page"},{"location":"#","page":"API Documentation","title":"API Documentation","text":"This will install Onda to the default package development directory, ~/.julia/dev/Onda.","category":"page"}]
}
