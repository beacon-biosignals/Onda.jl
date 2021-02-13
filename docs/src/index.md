# API Documentation

Below is the documentation for Onda.jl; for general information regarding the Onda Format itself, please see [beacon-biosignals/OndaFormat](https://github.com/beacon-biosignals/OndaFormat).

```@meta
CurrentModule = Onda
```

## Support For Generic Path-Like Types

Onda.jl attempts to be as agnostic as possible with respect to the storage system
that sample data, Arrow files, etc. are read from/written to. As such, any path-like
argument accepted by an Onda.jl API function should generically "work" as long
as the argument's type supports:

- `Base.read(path)::Vector{UInt8}` (return the bytes stored at `path`)
- `Base.write(path, bytes::Vector{UInt8})` (write `bytes` to the location specified by `path`)

For backends which support direct byte range access (e.g. S3), `Onda.read_byte_range` may
be overloaded for the backend's corresponding path type to enable further optimizations:

```@docs
Onda.read_byte_range
```





<!-- ## `Dataset` API -->




<!-- Note that Onda.jl's API follows a specific philosophy with respect to property access: users are generally expected to access fields via Julia's `object.fieldname` syntax, but should only *mutate* objects via the exposed API methods documented below.

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
==(::Samples, ::Samples)
validate_samples
channel
channel_count
sample_count
encode
encode!
decode
decode!
```

## Support For Generic Path-Like Types

Onda's Paths API directly underlies its Dataset API, providing an abstraction
layer that can be overloaded to support new storage backends for sample data and
recording metadata. This API's fallback implementation supports any path-like
type `P` that supports:

- `Base.read(::P)`
- `Base.write(::P, bytes::Vector{UInt8})`
- `Base.rm(::P; force, recursive)`
- `Onda.read_byte_range` (see signatures documented below)

```@docs
read_recordings_file
write_recordings_file
samples_path
read_samples
write_samples
read_byte_range
```

## LPCM Format (De)serialization API

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
Onda.file_format_constructor
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
``` -->
