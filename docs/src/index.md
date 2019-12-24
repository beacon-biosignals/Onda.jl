# API Documentation

Below is the documentation for all functions exported by Onda.jl. For general information regarding the Onda format, please see [beacon-biosignals/OndaFormat](https://github.com/beacon-biosignals/OndaFormat).

```@meta
CurrentModule = Onda
```

Note that Onda.jl's API follows a specific philosophy with respect to property access: users are generally expected to access fields via Julia's `object.fieldname` syntax, but should only *mutate* objects via the exposed API methods documented below.

## `Dataset`

```@docs
Dataset
create_recording!
load
store!
delete!
save_recordings_file
```

## Onda Metadata Objects

```@docs
Signal
signal_from_template
Annotation
Recording
annotate!
```

## `Samples`

```@docs
Samples
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
```

## Serialization

```@docs
AbstractLPCMSerializer
serializer
deserialize_lpcm
serialize_lpcm
LPCM
LPCMZst
```
