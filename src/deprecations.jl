#####
##### upgrades/deprecations
#####
# For some functions below, we handroll deprecations via `@warn`.
#
# In these cases, we don't use `@deprecate` because the method we're "redirecting to" for the deprecation path
# (e.g. `_deprecated_read_table`) is different than the method that we're suggesting downstream callers use
# instead (`Legolas.read`). `Base.depwarn` could possibly be utilized here, but isn't an officially documented
# function (though it's probably fine to use in practice). Thus, we settle for using `@warn ... maxlog=1`.

function _deprecated_read_table(io_or_path, schema=nothing)
    table = Legolas.read_arrow(io_or_path)
    schema isa Legolas.Schema && Legolas.validate(table, schema)
    return table
end

function read_signals(io_or_path; validate_schema::Bool=true)
    @warn "`Onda.read_signals(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead" maxlog=1
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.signal@1") : nothing)
end
export read_signals

function read_annotations(io_or_path; validate_schema::Bool=true)
    @warn "`Onda.read_annotations(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead" maxlog=1
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.annotation@1") : nothing)
end
export read_annotations

@deprecate materialize Legolas.materialize
@deprecate gather Legolas.gather
@deprecate validate_on_construction validate_samples_on_construction
@deprecate Annotation(recording, id, span; custom...) Annotation(; recording, id, span, custom...)
@deprecate(Signal(recording, file_path, file_format, span, kind, channels, sample_unit,
                  sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
                  custom...),
           Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
                  sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                  custom...))
@deprecate(SamplesInfo(kind, channels, sample_unit,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate; custom...),
           SamplesInfo(; kind, channels, sample_unit,
                       sample_resolution_in_unit, sample_offset_in_unit,
                       sample_type, sample_rate, custom...))

function validate(::SamplesInfo)
    @warn "validate(::SamplesInfo) is deprecated; avoid invoking this method in favor of calling `validate(::Samples)`" maxlog=1
    return nothing
end