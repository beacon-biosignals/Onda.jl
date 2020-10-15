# API Documentation

Below is the documentation for all functions exported by Onda.jl. For general information regarding the Onda format, please see [beacon-biosignals/OndaFormat](https://github.com/beacon-biosignals/OndaFormat).

```@meta
CurrentModule = Onda
```

Note that Onda.jl's API follows a specific philosophy with respect to property access: users are generally expected to access fields via Julia's `object.fieldname` syntax, but should only *mutate* objects via the exposed API methods documented below.

## `Dataset` API

```@docs
Dataset
load
load_encoded
save
create_recording!
store!
delete!
Onda.validate_on_construction
```

## Onda Format Metadata

```@docs
Signal
validate_signal
signal_from_template
span
sizeof_samples
Annotation
Recording
set_span!
annotate!
```

## `Samples`

```@docs
Samples
validate_samples
channel
channel_count
sample_count
encode
encode!
decode
decode!
```

## `AbstractTimeSpan`

```@docs
AbstractTimeSpan
TimeSpan
contains
overlaps
shortest_timespan_containing
duration
time_from_index
index_from_time
```

## Paths API

Onda's Paths API directly underlies its Dataset API, providing an abstraction
layer that can be overloaded to support new storage backends for sample data and
recording metadata. This API's fallback implementation supports any path-like
type `P` that supports:

- `Base.read(::P)`
- `Base.write(::P, bytes::Vector{UInt8})`
- `Base.rm(::P; force, recursive)`
- `Base.joinpath(::P, ::AbstractString...)`
- `Base.mkpath(::P)` (note: this is allowed to be a no-op for storage backends which have no notion of intermediate directories, e.g. object storage systems)
- `Base.dirname(::P)`
- `Onda.read_byte_range` (see signatures documented below)

```@docs
read_recordings_file
write_recordings_file
samples_path
read_samples
write_samples
read_byte_range
```

## Serialization API

Onda's Serialization API underlies its Paths API, providing a storage-agnostic
abstraction layer that can be overloaded to support new file/byte formats for
(de)serializing LPCM-encodeable sample data. This API also facilitates low-level
streaming sample data (de)serialization and Onda metadata (de)serialization.

```@docs
deserialize_recordings_msgpack_zst
serialize_recordings_msgpack_zst
AbstractLPCMFormat
AbstractLPCMStream
deserializing_lpcm_stream
serializing_lpcm_stream
finalize_lpcm_stream
Onda.format_constructor_for_file_extension
format
deserialize_lpcm
deserialize_lpcm_callback
serialize_lpcm
LPCM
LPCMZst
```

## Upgrading Older Datasets to Newer Datasets

```@docs
Onda.upgrade_onda_format_from_v0_2_to_v0_3!
```
