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

## `*.onda.annotations.arrow`

```@docs
Annotation
read_annotations
write_annotations
merge_overlapping_annotations
```

## `*.onda.signals.arrow`

```@docs
Signal
SamplesInfo
validate
read_signals
write_signals
channel
channel_count
sample_count
sizeof_samples
```

## `Samples`

```@docs
Samples
==(::Samples, ::Samples)
channel
channel_count
sample_count
encode
encode!
decode
decode!
load
store
```

## LPCM (De)serialization API

Onda.jl's LPCM (De)serialization API facilitates low-level streaming sample
data (de)serialization and provides a storage-agnostic abstraction layer
that can be overloaded to support new file/byte formats for (de)serializing
LPCM-encodeable sample data.

```@docs
AbstractLPCMFormat
AbstractLPCMStream
LPCMFormat
LPCMZstFormat
format
deserialize_lpcm
serialize_lpcm
deserialize_lpcm_callback
deserializing_lpcm_stream
serializing_lpcm_stream
finalize_lpcm_stream
Onda.register_lpcm_format!
Onda.file_format_string
```

## Utilities

```@docs
Onda.gather
Onda.validate_on_construction
Onda.upgrade_onda_dataset_to_v0_5!
```
