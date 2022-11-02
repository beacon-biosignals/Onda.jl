# Upgrading From Older Versions Of Onda

## To v0.15 From v0.14

First, ensure your codebase is fully upgraded to Onda v0.14, including resolving all deprecation warnings.

From there, breaking changes include:

- Functionality that was "soft-deprecated" in Onda v0.14 (i.e. code would still work, but warnings would be raised) is now "hard-deprecated" as of Onda v0.15.

- Onda is now built atop Legolas v0.5, instead of Legolas v0.4. Users of Onda v0.15 must therefore upgrade their usage of Legolas to Legolas v0.5 (see [here for details](https://github.com/beacon-biosignals/Legolas.jl/pull/54)). One of the most significant implications of this breaking change is that `Annotation` and `Signal` (formerly, aliases of the old `Legolas.Row` type) have been replaced with `AnnotationV1` and `SignalV2` (subtypes of the new `Legolas.AbstractRecord` type). The latter types have slightly different semantics than the former, especially in that the new types do not propagate non-required fields in the same manner as the old types. Even though a comprehensive deprecation path isn't provided, invocations of `Annotation(...)`/`Signal(...)` will now throw a descriptive error with suggestions on how to upgrade.

- The addition of `onda.samples-info@2` and `onda.signal@2`, which replace `onda.samples-info@1` and `onda.signal@1` respectively. Onda still declares/provides these first-generation schemas, so that corresponding `Legolas.read` invocations may still work as expected, but all other Onda v0.15 API structures/functions utilize (and/or expect) the second-generation schemas. Onda v0.15 provides [`Onda.upgrade`](@ref) to conveniently upgrade first-generation data to the new generation.

- The functions `Onda.write_signals`, `Onda.write_annotations`, and `Onda.validate` have been soft-deprecated, and will thus continue to work - but will raise deprecation warnings - until the next breaking version update.

## To v0.14 From v0.13

Potentially breaking changes include:

- `SamplesInfo`'s `sample_type` field is now an `AbstractString` (see `sample_type` in https://github.com/beacon-biosignals/Onda.jl#columns) as opposed to a `DataType`. The [`sample_type`](@ref) function should now be used to retrieve this field as a `DataType`.

- Since `SampleInfo`/`Signal`/`Annotation` are now [`Legolas.Row` aliases](https://beacon-biosignals.github.io/Legolas.jl/stable/#Legolas.Row), any instance of these types may contain additional author-provided fields atop required fields. Thus, code that relies on these types containing a specific number of fields (or similarly, a specific field order) might break in generic usage.

Otherwise, there are no intended breaking changes from v0.13 to v0.14 that do not have a supported deprecation path. These deprecation paths will be maintained for at least one `0.x` release cycle. To upgrade your code, simply run your code/tests with Julia's `--depwarn=yes` flag enabled and make the updates recommended by whatever deprecation warnings arise.

## To v0.14 From v0.11 Or Older

Before Onda.jl v0.12, signal and annotation metadata was stored (both in-memory, and serialized) in a nested `Dict`-like structure wrapped by the `Onda.Dataset` type. In the Onda.jl v0.12 release, we dropped the `Onda.Dataset` type and instead switched to storing signal and annotation metadata in separate Arrow tables. See [here](https://github.com/beacon-biosignals/OndaFormat/issues/25) for the motivations behind this switch.

Tips for upgrading:

- Onda.jl v0.13 contains a convenience function, `Onda.upgrade_onda_dataset_to_v0_5!`, to automatically upgrade old datasets to the new format. This function has since been removed after several deprecation cycles, but it can still be invoked as needed by `Pkg.add`ing/`Pkg.pin`ing Onda at `version="0.13"`. See [the function's docstring](https://github.com/beacon-biosignals/Onda.jl/blob/eb2623dc3fe436850667c646aa7c329485c61046/src/Onda.jl#L34-L70) for more details.

- The newer tabular format enables consumers/producers to easily impose whatever indexing structure is most convenient for their use case, including the old format's indexing structure. This can be useful for upgrading old code that utilized the old `Onda.Recording`/`Onda.Dataset` types. Specifically, the [Onda Tour](https://github.com/beacon-biosignals/Onda.jl/blob/master/examples/tour.jl) shows how tables in the new format can indexed in the same manner as the old format via a few simple commands. This tour is highly recommended for authors that are upgrading old code, as it directly demonstrates how to perform many common Onda operations (e.g. sample data storing/loading) using the latest version of the package.

- The following changes were made to `Onda.Signal`:
    - Formerly, each signal was stored as the pair `kind::Symbol => metadata` within a dictionary keyed to a specific `recording::UUID`. Now that each signal is a self-contained table row, each signal contains its own `recording::UUID` and `kind::String` fields. Note that, unlike the old format, the new data model allows the existence of multiple signals of the same `kind` in the same `recording` (see [here](https://github.com/beacon-biosignals/Onda.jl/README.md#columns) for guidance on the interpretation of such data). If a primary key is needed to identify individual sample data artifacts, use the `file_path` field instead of the `kind` field.
    - The `file_extension`/`file_options` fields were replaced by the `file_path`/`file_format` fields.
    - The `channel_names::Vector{Symbol}` field was changed to `channels::Vector{String}`.
    - The `start_nanosecond`/`stop_nanosecond` fields were replaced with a single `span::TimeSpan` field.
    - The `sample_unit::Symbol` field was changed to `sample_unit::String`.

- The following changes were made to `Onda.Annotation`:
    - Formerly, annotations were stored as a simple list keyed to a specific `recording::UUID`. Now that each annotation is a self-contained table row, each annotation contains its own `recording::UUID` and `id::UUID` fields. The latter field serves as a primary key to identify individual annotations.
    - The `start_nanosecond`/`stop_nanosecond` fields were replaced with a single `span::TimeSpan` field.
    - The `value` field was dropped in favor of allowing annotation authors to provide arbitrary custom columns tailored to their use case.
