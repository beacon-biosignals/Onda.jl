# Upgrading From Older Versions Of Onda

## To v0.14 From v0.13

There are no intended breaking changes from v0.13 to v0.14 that do not have a supported deprecation
path. These deprecation paths will be maintained for at least one `0.x` release cycle. To upgrade
your code, simply run your code/tests with Julia's `--depwarn=yes` flag enabled and make the updates
recommended by whatever deprecation warnings arise.

## To v0.14 From v0.11 Or Older

Before Onda.jl v0.12, signal and annotation metadata was stored (both in-memory, and serialized) in
a nested `Dict`-like structure wrapped by the `Onda.Dataset` type. In the Onda.jl v0.12 release, we
dropped the `Onda.Dataset` type and instead switched to storing signal and annotation metadata in
separate Arrow tables. See [here](TODO) for the motivations behind this switch.

Tips for upgrading:

- Onda.jl v0.13 contains a convenience function, `Onda.upgrade_onda_dataset_to_v0_5!`, to automatically
upgrade old datasets to the new format. This function has since been removed after several deprecation
cycles, but it can still be invoked as needed by `Pkg.add`ing/`Pkg.pin`ing Onda at `version="0.13"`.

- The newer tabular format enables consumers/producers to easily impose whatever indexing structure is most
convenient for their use case, including the old format's indexing structure. This can be useful for upgrading
old code that utilized the old `Onda.Recording`/`Onda.Dataset` types. Specifically, the [Onda Tour](TODO) shows
how tables in the new format can indexed in the same manner as the old format via a few simple commands. This
tour is highly recommended for authors that are upgrading old code, as it directly demonstrates how to perform
many common Onda operations (e.g. sample data storing/loading) using the latest version of the package.

- The following field names changed for `Onda.Signal`: TODO

- The following field names changed for `Onda.Annotation`: TODO

