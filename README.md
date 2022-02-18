# Onda.jl

[![CI](https://github.com/beacon-biosignals/Onda.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/beacon-biosignals/Onda.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/beacon-biosignals/Onda.jl/branch/master/graph/badge.svg?token=D0bcI0Rtsw)](https://codecov.io/gh/beacon-biosignals/Onda.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://beacon-biosignals.github.io/Onda.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://beacon-biosignals.github.io/Onda.jl/dev)
[![Code Style: YASGuide](https://img.shields.io/badge/code%20style-yas-violet.svg)](https://github.com/jrevels/YASGuide)

[Take The Tour](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples/tour.jl)

[See Other Examples](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples)

Onda.jl is a Julia package for high-throughput manipulation of structured LPCM signal data across arbitrary domain-specific encodings, file formats and storage layers.

## The Onda Format Specification

**Onda** is a lightweight format defined atop [Apache Arrow](https://arrow.apache.org/) for storing and manipulating sets of multi-sensor, multi-channel, LPCM-encodable, annotated, time-series recordings.

This format is intentionally language-agnostic; any consumer/producer that supports Apache Arrow can read/write Onda-compliant Arrow tables. For the sake of convenience, the Onda specification resides here (in the Onda.jl repository) and leverages the [Legolas](https://github.com/beacon-biosignals/Legolas.jl) framework to both define and version the Arrow table schemas relevant to the format.

### Terminology

This document uses the term...

- ...**"LPCM"** to refer to [linear pulse code modulation](https://en.wikipedia.org/wiki/Pulse-code_modulation), a form of signal encoding where multivariate waveforms are digitized as a series of samples uniformly spaced over time and quantized to a uniformly spaced grid.

- ...**"signal"** to refer to the digitized output of a process. A signal is comprised of metadata (e.g. LPCM encoding, channel information, sample data path/format information, etc.) and associated multi-channel sample data.

- ...**"recording"** to refer a collection of one or more signals recorded simultaneously over some time period.

- ...**"annotation"** to refer to a piece of (meta)data associated with a specific time span within a specific recording.

### Design Principles

#### Onda is useful...

- ...when segments of a signal can fit in memory simultaneously, but an entire signal cannot.
- ...when each signal in each recording in your dataset can fit in memory, but not all signals in each recording can fit in memory simultaneously.
- ...when each recording in your dataset can fit in memory, but not all recordings in your dataset can fit in memory simultaneously.
- ...when your dataset's signals benefit from sensor-specific encodings/compression codecs.
- ...as an intermediate target format for wrangling unstructured signal data before bulk ingestion into a larger data store.
- ...as an intermediate target format for local experimentation after bulk retrieval from a larger data store.
- ...as a format for sharing datasets comprised of several gigabytes to several terabytes of signal data.
- ...as a format for sharing datasets comprised of hundreds to hundreds of thousands of recordings.

#### Onda's design must...

- ...depend only upon technologies with standardized, implementation-agnostic specifications that are well-used across multiple application domains.
- ...support recordings where each signal in the recording may have a unique channel layout, physical unit resolution, bit depth and sample rate.
- ...be well-suited for ingestion into/retrieval from...
    - ...popular distributed analytics tools (e.g. Spark, TensorFlow).
    - ...traditional databases (e.g. PostgresSQL, Cassandra).
    - ...object-based storage systems (e.g. S3, GCP Cloud Storage).
- ...enable metadata, annotations etc. to be stored and processed separately from raw sample data without significant communication overhead.
- ...enable extensibility without sacrificing interpretability. New signal encodings, annotations, sample data file formats, etc. should all be user-definable by design.
- ...be simple enough that a decent programmer (with Google access) should be able to fully interpret (and write performant parsers for) an Onda dataset without ever reading Onda documentation.

#### Onda is not...

- ...a sample data file format. Onda allows dataset authors to utilize whatever file format is most appropriate for a given signal's sample data, as long as the author provides a mechanism to deserialize sample data from that format to a standardized interleaved LPCM representation.
- ...a transactional database. The majority of an Onda dataset's mandated metadata is stored in tabular manifests containing recording information, signal descriptions, annotations etc. This simple structure is tailored towards Onda's target regimes (see above), and is not intended to serve as a persistent backend for external services/applications.
- ...an analytics platform. Onda seeks to provide a data model that is purposefully structured to enable various sorts of analysis, but the format itself does not mandate/describe any specific implementation of analysis utilities.

### Schema Definitions

The Onda format primarily consists of a collection of interelated [Legolas](https://github.com/beacon-biosignals/Legolas.jl) schemas:

- `onda.signal`: metadata that describes a **signal** as previously defined, including LPCM encoding, channel information, sample data path/format, etc.
- `onda.annotation`: metadata that describes an **annotation** as previously defined, including the recording of interest, the time span of interest, etc.

These schemas are largely orthogonal to one another - here's nothing inherent to the Onda format that prevents a dataset producer/consumer from separately constructing/manipulating/transferring/analyzing an `onda.signal` table and `onda.annotation` table. Furthermore, there's nothing that prevents dataset producers/consumers from working with multiple tables of the same schema, referencing the same set of recordings (e.g. splitting all of a dataset's annotations across multiple `onda.annotation` tables).

The following sections provide [the version integer](https://beacon-biosignals.github.io/Legolas.jl/stable/schema/), per-column documentation, and examples for each of the above Legolas schemas. In accordance with the Legolas framework, a table is considered to comply with a given schema as long as the specified required columns for that schema are present in any order. While per-column documentation refers to the [logical types defined by the Arrow specification](https://github.com/apache/arrow/blob/master/format/Schema.fbs), Onda reader/writer implementations may additionally employ Arrow extension types that directly alias a column's specified logical type in order to support application-level features (first-class UUID support, custom `file_path` type support, etc.).

#### `onda.signal@1`

##### Columns

- `recording` (128-bit `FixedSizeBinary`): The UUID identifying the recording with which the signal is associated.
- `file_path` (`Utf8`): A string identifying the location of the signal's associated sample data file. This string must either be a [valid URI](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier) or a file path relative to the location of the `onda.signal` table itself.
- `file_format` (`Utf8`): A string identifying the format of the signal's associated sample data file. All Onda reader/writer implementations must support the following file formats (and may define and support additional values as desired):
    - `"lpcm"`: signals are stored in raw interleaved LPCM format (see format description below).
    - `"lpcm.zst"`: signals stored in raw interleaved LPCM format and compressed via [`zstd`](https://github.com/facebook/zstd)
- `span` (`Struct`): The signal's time span within the recording. This structure has two fields:
    - `start` (`Duration` w/ `NANOSECOND` unit): The start offset in nanoseconds from the beginning of the recording. The minimum possible value is `0`.
    - `stop` (`Duration` w/ `NANOSECOND` unit): The stop offset in nanoseconds (exclusive) from the beginning of the recording. This value must be greater than `start`.
- `kind` (`Utf8`): A string identifying the kind of signal that the row represents. Valid `kind` values are alphanumeric, nonempty, lowercase, `snake_case`, and contain no whitespace, punctuation, or leading/trailing underscores.
- `channels` (`List` of `Utf8`): A list of strings where the `i`th element is the name of the signal's `i`th channel. A valid channel name...
    - ...is alphanumeric, nonempty, lowercase, `snake_case`, and contain no whitespace, punctuation, or leading/trailing underscores.
    - ...conforms to one of the following formats:
        - "reference format": `a-b`, where `a` and `b` are valid channel names. Furthermore, to allow arbitrary cross-signal referencing, `a` and/or `b` may be channel names from other signals contained in the recording. If this is the case, such a name must be qualified in the format `signal_name.channel_name`. For example, an `eog` signal might have a channel named `left-eeg.m1` (the left eye electrode referenced to the mastoid electrode from a 10-20 EEG signal).
        - "linked format": `(a+b)/c`, where `a`, `b`, and `c` are valid channel names. Note that `c` need not refer to an actual channel, as in the case of a linked mastoid reference `(m1+m2)/2`.
    - ...is unique amongst the other channel names in the signal. In other words, duplicate channel names within the same signal are disallowed.
- `sample_unit` (`Utf8`): The name of the signal's canonical unit as a string. This string should conform to the same format as `kind` (alphanumeric, nonempty, lowercase, `snake_case`, and contain no whitespace, punctuation, or leading/trailing underscores), should be singular and not contain abbreviations (e.g. `"uV"` is bad, `"microvolt"` is good; `"l/m"` is bad, `"liter_per_minute"` is good).
- `sample_resolution_in_unit` (`Int` or `FloatingPoint`): The signal's resolution in its canonical unit. This value, along with the signal's `sample_type` and `sample_offset_in_unit` fields, determines the signal's LPCM quantization scheme.
- `sample_offset_in_unit`  (`Int` or `FloatingPoint`): The signal's zero-offset in its canonical unit (thus allowing LPCM encodings that are centered around non-zero values).
- `sample_type` (`Utf8`): The primitive scalar type used to encode each sample in the signal. Valid values are:
    - `"int8"`: signed little-endian 1-byte integer
    - `"int16"`: signed little-endian 2-byte integer
    - `"int32"`: signed little-endian 4-byte integer
    - `"int64"`: signed little-endian 8-byte integer
    - `"uint8"`: unsigned little-endian 1-byte integer
    - `"uint16"`: unsigned little-endian 2-byte integer
    - `"uint32"`: unsigned little-endian 4-byte integer
    - `"uint64"`: unsigned little-endian 8-byte integer
    - `"float32"`: 32-bit floating point number
    - `"float64"`: 64-bit floating point number
- `sample_rate` (`Int` or `FloatingPoint`): The signal's sample rate.

Note that this schema allows for the existence of multiple `onda.signal` instances with the same `kind` and `recording`. In this instance, these `onda.signal` instances should be interpreted as digitized outputs of the same underlying process at their respective `span`s, thus enabling the representation/storage of discontiguous/overlapping sample data. Beyond this definition, further specification for the resolution of sample data discontinuities and/or overlaps for specific `kind`s/`recording`s/etc. is left to downstream, use-case-specific extensions of the `onda.signal` schema. For example, there may exist an `onda.signal` with `kind="eeg"` and `span=(start=Nanosecond(0), stop=Nanosecond(1e9))`, and another with the same `recording`/`kind` but with `span=(start=Nanosecond(2e9), stop=Nanosecond(3e9))`; downstream consumers may interpret this as a single EEG signal that is sampled for 1 second starting at the beginning of the recording, followed by a 1 second gap, followed by another second of sampling.

When feasible in practice, it is recommended that data producers manually concatenate discontiguous sample data into a single `onda.signal` and use `NaN` values to represent unsampled regions, rather than represent discontiguous segments via separate `onda.signal`s, as the former approach is often more convenient than the latter for downstream consumers.

##### Examples

| `recording`                          | `file_path`                                        | `file_format`                                            | `span`                       | `kind`     | `channels`                              | `sample_unit` | `sample_resolution_in_unit` | `sample_offset_in_unit` | `sample_type` | `sample_rate` | `my_custom_value`             |
|--------------------------------------|----------------------------------------------------|----------------------------------------------------------|------------------------------|------------|-----------------------------------------|---------------|-----------------------------|-------------------------|---------------|---------------|-------------------------------|
| `0xb14d2c6d8d844e46824f5c5d857215b4` | `"./relative/path/to/samples.lpcm"`                | `"lpcm"`                                                 | `(start=10e9, stop=10900e9)` | `"eeg"`    | `["fp1", "f3", "f7", "fz", "f4", "f8"]` | `"microvolt"` | `0.25`                      | `3.6`                   | `"int16"`     | `256`         | `"this is a value"`           |
| `0xb14d2c6d8d844e46824f5c5d857215b4` | `"s3://bucket/prefix/obj.lpcm.zst"`                | `"lpcm.zst"`                                             | `(start=0, stop=10800e9)`    | `"ecg"`    | `["avl", "avr"]`                        | `"microvolt"` | `0.5`                       | `1.0`                   | `"int16"`     | `128.3`       | `"this is a different value"` |
| `0x625fa5eadfb24252b58d1eb350fa7df6` | `"s3://other-bucket/prefix/obj_with_no_extension"` | `"flac"`                                                 | `(start=100e9, stop=500e9)`  | `"audio"`  | `["left", "right"]`                     | `"scalar"`    | `1.0`                       | `0.0`                   | `"float32"`   | `44100`       | `"this is another value"`     |
| `0xa5c01f0e50fe4acba065fcf474e263f5` | `"./another-relative/path/to/samples"`             | `"custom_price_format:{\"parseable_json_parameter\":3}"` | `(start=0, stop=3600e9)`     | `"price"`  | `["price"]`                             | `"dollar"`    | `0.01`                      | `0.0`                   | `"uint32"`    | `50.75`       | `"wow what a great value"`    |

##### Sample Data Files

The sample data file referenced by a signal's `file_path` field must be encoded as specified by that signal's `sample_type`, `sample_resolution_in_unit`, and `sample_offset_in_unit` fields, serialized to raw LPCM format, and formatted as specified by the signal's `file_format` field.

While Onda explicitly supports arbitrary choice of file format for serialized sample data via the `file_format` field, Onda reader/writer implementations should support (de)serialization of sample data from any implementation-supported format into the following standardized interleaved LPCM in-memory representation:

Given an `n`-channel signal, the byte offset for the `i`th channel value in the `j`th multichannel sample is given by `((i - 1) + (j - 1) * n) * byte_width(signal.sample_type)`. This layout can be expressed in the following table (where `w = byte_width(signal.sample_type)`):

| Byte Offset                 | Value                                |
|-----------------------------|--------------------------------------|
| 0                           | 1st channel value for 1st sample     |
| w                           | 2nd channel value for 1st sample     |
| ...                         | ...                                  |
| (n - 1) * w                 | `n`th channel value for 1st sample   |
| (n + 0) * w                 | 1st channel value for 2nd sample     |
| (n + 1) * w                 | 2nd channel value for 2nd sample     |
| ...                         | ...                                  |
| (2*n - 1) * w               | `n`th channel value for 2nd sample   |
| (2*n + 0) * w               | 1st channel value for 3rd sample     |
| (2*n + 1) * w               | 2nd channel value for 3rd sample     |
| ...                         | ...                                  |
| (3*n - 1) * w               | `n`th channel value for 3rd sample   |
| ...                         | ...                                  |
| ((i - 1) + (j - 1) * n) * w | `i`th channel value for `j`th sample |
| ...                         | ...                                  |

Values are represented in little-endian format.

An individual value in a multichannel sample can be converted to its encoded representation from its canonical unit representation via:

```
encoded_value = (decoded_value - sample_offset_in_unit) / sample_resolution_in_unit
```

where the division is followed/preceded by whatever quantization strategy is chosen by the user (e.g. rounding/truncation/dithering etc). Complementarily, an individual value in a multichannel sample can be converted ("decoded") from its encoded representation to its canonical unit representation via:

```
decoded_value = (encoded_value * sample_resolution_in_unit) + sample_offset_in_unit
```

#### `onda.annotation@1`

##### Columns

- `recording` (128-bit `FixedSizeBinary`): The UUID identifying the recording with which the annotation is associated.
- `id` (128-bit `FixedSizeBinary`): The UUID identifying the annotation.
- `span` (`Struct`): The annotation's time span within the recording. This has the same structure as the `onda.signal` schema's `span` column (specified in the previous section).

##### Examples

| `recording`                          | `id`                                 | `span`                  | `my_custom_value`             |
|--------------------------------------|--------------------------------------|-------------------------|-------------------------------|
| `0xb14d2c6d8d844e46824f5c5d857215b4` | `0x81b17ea902504371954e7b8b167236a6` | `(start=5e9, stop=6e9)` | `"this is a value"`           |
| `0xb14d2c6d8d844e46824f5c5d857215b4` | `0xdaebbd1b0cab4b89acdde51f9c9a1d7c` | `(start=3e9, stop=7e9)` | `"this is a different value"` |
| `0x625fa5eadfb24252b58d1eb350fa7df6` | `0x11aeeb4b743149808b53547642652f0e` | `(start=1e9, stop=2e9)` | `"this is another value"`     |
| `0xa5c01f0e50fe4acba065fcf474e263f5` | `0xbc0be95e3da2495391daba233f035acc` | `(start=2e9, stop=3e9)` | `"wow what a great value"`    |

## Potential Alternatives

In this section, we describe several alternative technologies/solutions considered during Onda's design.

- Parquet: We chose to base Onda's tabular data specification on Arrow, rather than Parquet, because the former is meaningful as an in-memory/interchange format, not just as a storage format. Onda consumers/producers could, of course, (de)serialize Onda-formatted Arrow tables to/from Parquet format as they like.

- Various potential sample data storage formats: Early prototypes of Onda were not agnostic to the user's choice of sample data file format, but instead took a more opinionated approach. Many technologies were considered as a generic underlying file format, including Avro ([motivated by Uber's image storage use case](https://eng.uber.com/hdfs-file-format-apache-spark/)), [NPY](https://numpy.org/devdocs/reference/generated/numpy.lib.format.html), [Zarr](https://zarr.readthedocs.io/en/stable/), and more. The current version of Onda allows reader/writer implementations to support any of these formats as (de)serialization targets, but does not mandate support for any of them. This enables Onda producers/consumers to leverage the format/codec that best suits their domain of interest (e.g. FLAC for audio).

- HDF5: While featureful, ubiquitous, and technically based on an open standard, HDF5 is [infamous for being a hefty dependency with a fairly complex reference implementation](https://cyrille.rossant.net/moving-away-hdf5/). While HDF5 solves many problems inherent to filesystem-based storage, most use cases for Onda involve storing large binary blobs in domain-specific formats that already exist quite naturally as files on a filesystem, or as objects in an object storage system. Though it was decided that Onda should not explicitly depend on HDF5, nothing technically precludes Onda-formatted content from being stored in HDF5. For practical purposes, however, Onda readers/writers may not necessarily automatically be able to read such a dataset unless they explicitly support HDF5 as a storage layer (since HDF5 support isn't mandated by the format).

- EDF/MEF/etc.: Onda was originally motivated by bulk electrophysiological dataset manipulation, a domain in which there are many different recording file formats that are all generally designed to support a one-file-per-recording use case and are constrained to certain domain-specific assumptions (e.g. specific bit depth assumptions, annotations stored within signal artifacts, etc.). Technically, since Onda itself is agnostic to choice of file formats used for signal serialization, one could store Onda sample data in EDF/MEF.

- BIDS: BIDS is an alternative option for storing neuroscience datasets. As mentioned above, Onda's original motivation is electrophysiological dataset manipulation, so BIDS appeared to be a highly relevant candidate. Unfortunately, BIDS restricts EEG data to [very specific file formats](https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/03-electroencephalography.html#eeg-recording-data) and also does not account for the plurality of LPCM-encodable signals that Onda seeks to handle generically.

- MessagePack: An early version of Onda used MessagePack to store all signal/annotation metadata. See [this issue](https://github.com/beacon-biosignals/OndaFormat/issues/25) for background on the switch to Arrow.

- JSON: In early Onda prototypes, JSON was used to serialize signal/annotation metadata. While JSON has the advantage of being ubiquitous/simple/flexible/human-readable, the performance overhead of textual decoding/encoding was greater than desired for datasets with lots of annotations. In comparison, switching to MessagePack yielded a ~3x performance increase in (de)serialization for practical usage. The subsequent switch from MessagePack to Arrow in modern versions of the Onda format yielded even greater (de)serialization improvements.

- BSON: BSON was considered as a potential serialization format for signal/annotation metadata. In pre-Arrow versions of Onda, MessagePack was chosen over BSON due to the latter's relative complexity compared to the former. In Onda's current version, BSON remains less preferable than Arrow from a tabular data representation perspective.

### Older Versions Of The Format

Before the Onda.jl v0.14 release, the Onda Format Specification resided in a separate repository. This repository is now archived, but its contents and issue tracker are still available for historical purposes in a read-only fashion at https://github.com/beacon-biosignals/OndaFormat.
