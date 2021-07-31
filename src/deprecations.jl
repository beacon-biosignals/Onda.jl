#####
##### upgrades/deprecations
#####

# For some functions below, we use `Base.depwarn`.
#
# In these cases, we don't use `@deprecate` because the method we're "redirecting to" for the deprecation path
# (e.g. `_deprecated_read_table`) is different than the method that we're suggesting downstream callers use
# instead (`Legolas.read`).

using Base: depwarn

function _deprecated_read_table(io_or_path, schema=nothing)
    table = Legolas.read_arrow(io_or_path)
    schema isa Legolas.Schema && Legolas.validate(table, schema)
    return table
end

function read_signals(io_or_path; validate_schema::Bool=true)
    depwarn("`Onda.read_signals(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead", :read_signals)
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.signal@1") : nothing)
end
export read_signals

function read_annotations(io_or_path; validate_schema::Bool=true)
    depwarn("`Onda.read_annotations(io_or_path)` is deprecated, use `Legolas.read(io_or_path)` instead", :read_annotations)
    return _deprecated_read_table(io_or_path, validate_schema ? Legolas.Schema("onda.annotation@1") : nothing)
end
export read_annotations

@deprecate materialize Legolas.materialize false
@deprecate gather Legolas.gather false
@deprecate validate_on_construction validate_samples_on_construction false

@deprecate(validate_signal_schema(s),
           isnothing(s) ? nothing : Legolas.validate(s, Legolas.Schema("onda.signal@1")),
           false)

@deprecate(validate_annotation_schema(s),
           isnothing(s) ? nothing : Legolas.validate(s, Legolas.Schema("onda.annotation@1")),
           false)

if VERSION >= v"1.5"
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
else
    @deprecate(Annotation(recording, id, span; custom...),
               @compat Annotation(; recording, id, span, custom...))
    @deprecate(Signal(recording, file_path, file_format, span, kind, channels, sample_unit,
                      sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
                      custom...),
               @compat Signal(; recording, file_path, file_format, span, kind, channels, sample_unit,
                              sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate,
                              custom...))
    @deprecate(SamplesInfo(kind, channels, sample_unit,
                           sample_resolution_in_unit, sample_offset_in_unit,
                           sample_type, sample_rate; custom...),
               @compat SamplesInfo(; kind, channels, sample_unit,
                                   sample_resolution_in_unit, sample_offset_in_unit,
                                   sample_type, sample_rate, custom...))
end

function validate(::SamplesInfo)
    depwarn("`validate(::SamplesInfo)` is deprecated; avoid invoking this method in favor of calling `validate(::Samples)`", :validate)
    return nothing
end
