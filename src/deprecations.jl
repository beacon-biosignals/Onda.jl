#####
##### Onda v0.14 -> v0.15
#####

@deprecate write_annotations(path_or_io, table; kwargs...) Legolas.write(path_or_io, table, AnnotationV1SchemaVersion(); kwargs...)

@deprecate write_signals(path_or_io, table; kwargs...) Legolas.write(path_or_io, table, SignalV2SchemaVersion(); kwargs...)

@deprecate validate(s) validate_samples(s.data, s.info, s.encoded) false

function Annotation(args...; kwargs...)
    error("""
          `Onda.Annotation` has been replaced by `Onda.AnnotationV1`.

          If you're upgrading invocations of `Onda.Annotation` that *only* accept the required fields defined by
          the `onda.annotation@1` schema version, try out the following code in place of your original invocation:

              AnnotationV1(fields)

          If you're upgrading invocations of `Onda.Annotation` that may accept non-required fields, you might try the following:

              Tables.rowmerge(fields, AnnotationV1(fields))::NamedTuple
          """)
end

function Signal(args...; kwargs...)
    error("""
          `Onda.Signal` has been replaced by `Onda.SignalV2`.

          If you're upgrading invocations of `Onda.Signal` that *only* accept the required fields defined by the `onda.signal@1`
          schema version, try out the following code in place of your original invocation:

              Onda.upgrade(Onda.SignalV1(fields), SignalV2SchemaVersion())::SignalV2

          Or, if possible, you can manually upgrade `fields` itself to comply with `onda.signal@2` and simply invoke:

              SignalV2(upgraded_fields)

          If you're upgrading invocations of `Onda.Signal` that may accept non-required fields, you might try one of the following:

              Tables.rowmerge(fields, Onda.upgrade(Onda.SignalV1(fields), SignalV2SchemaVersion())::SignalV2)::NameTuple
              Tables.rowmerge(upgraded_fields, SignalV2(upgraded_fields))::NameTuple
          """)
end

convert_number_to_lpcm_sample_type(x::LPCM_SAMPLE_TYPE_UNION) = x
convert_number_to_lpcm_sample_type(x) = Float64(x)

@version SamplesInfoV1 begin
    kind::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_resolution_in_unit)
    sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_offset_in_unit)
    sample_type::String = onda_sample_type_from_julia_type(sample_type)
    sample_rate::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_rate)
end

Legolas.accepted_field_type(::SamplesInfoV1SchemaVersion, ::Type{String}) = AbstractString
Legolas.accepted_field_type(::SamplesInfoV1SchemaVersion, ::Type{Vector{String}}) = AbstractVector{<:AbstractString}

function _validate_signal_kind(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal kind (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

@version SignalV1 > SamplesInfoV1 begin
    recording::UUID = UUID(recording)
    file_path::(<:Any)
    file_format::String = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format
    span::TimeSpan = TimeSpan(span)
    kind::String = _validate_signal_kind(kind)
    channels::Vector{String} = _validate_signal_channels(channels)
    sample_unit::String = _validate_signal_sample_unit(sample_unit)
end

Legolas.accepted_field_type(::SignalV1SchemaVersion, ::Type{String}) = AbstractString
Legolas.accepted_field_type(::SignalV1SchemaVersion, ::Type{Vector{String}}) = AbstractVector{<:AbstractString}

"""
    Onda.upgrade(from::SignalV1, ::SignalV2SchemaVersion)

Return a `SignalV2` instance that represents `from` in the `SignalV2SchemaVersion` format.

The fields of the output will match `from`'s fields, except:

- The `kind` field will be removed.
- The `sensor_label=from.kind` field will be added.
- The `sensor_type=from.kind` field will be added.
"""
function upgrade(from::SignalV1, ::SignalV2SchemaVersion)
    return SignalV2(; from.recording, from.file_path, from.file_format,
                    from.span, sensor_label=from.kind, sensor_type=from.kind,
                    from.channels, from.sample_unit, from.sample_resolution_in_unit,
                    from.sample_offset_in_unit, from.sample_type, from.sample_rate)
end

# Not quite a deprecation, but we will backport `record_merge` for our own purposes
if pkgversion(Legolas) < v"0.5.18"
    function record_merge(record::Legolas.AbstractRecord; fields_to_merge...)
        # Avoid using `typeof(record)` as can cause constructor failures with parameterized 
        # record types.
        R = Legolas.record_type(Legolas.schema_version_from_record(record))
        return R(Tables.rowmerge(record; fields_to_merge...))
    end
else
    using Legolas: record_merge
end
