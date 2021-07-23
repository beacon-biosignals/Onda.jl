# API Documentation

Below is the API documentation for Onda.jl.

For general information regarding the Onda Format itself, please see [beacon-biosignals/OndaFormat](https://github.com/beacon-biosignals/OndaFormat).

For a nice introduction to the package, see the [Onda Tour](https://github.com/beacon-biosignals/Onda.jl/blob/master/examples/tour.jl).

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
merge_overlapping_annotations
```

## `onda.signal`

```@docs
Signal
SamplesInfo
channel(x, name)
channel(x, i::Integer)
channel_count(x)
sample_count(x, duration::Period)
sizeof_samples(x, duration::Period)
sample_type(x)
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
Onda.mmap
store
channel(samples::Samples, name)
channel(samples::Samples, i::Integer)
channel_count(samples::Samples)
sample_count(samples::Samples)
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
Onda.validate_samples_on_construction
Onda.upgrade_onda_dataset_to_v0_5!
Onda.downgrade_onda_dataset_to_v0_4!
```

## Developer Installation

To install Onda for development, run:

```
julia -e 'using Pkg; Pkg.develop(PackageSpec(url="https://github.com/beacon-biosignals/Onda.jl"))'
```

This will install Onda to the default package development directory, `~/.julia/dev/Onda`.