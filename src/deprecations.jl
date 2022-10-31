#####
##### Onda v0.14 -> v0.15
#####
# TODO
#=
"""
    write_annotations(io_or_path, table; kwargs...)

Invoke/return `Legolas.write(path_or_io, annotations, Annotation(1); kwargs...)`.
"""
write_annotations(path_or_io, annotations; kwargs...) = Legolas.write(path_or_io, annotations, Annotation(1); kwargs...)

"""
    write_signals(io_or_path, table; kwargs...)

Invoke/return `Legolas.write(path_or_io, signals, Signal(2); kwargs...)`.
"""
write_signals(path_or_io, signals; kwargs...) = Legolas.write(path_or_io, signals, Signal(2); kwargs...)

function _validate_signal_kind(x)
    is_lower_snake_case_alphanumeric(x) || throw(ArgumentError("invalid signal kind (must be lowercase/snakecase/alphanumeric): $x"))
    return x
end

@schema("onda.samples-info@1",
        kind::AbstractString = convert(String, kind),
        channels::AbstractVector{<:AbstractString} = convert(Vector{String}, channels),
        sample_unit::AbstractString = convert(String, sample_unit),
        sample_resolution_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_resolution_in_unit),
        sample_offset_in_unit::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_offset_in_unit),
        sample_type::AbstractString = onda_sample_type_from_julia_type(sample_type),
        sample_rate::LPCM_SAMPLE_TYPE_UNION = convert_number_to_lpcm_sample_type(sample_rate))

@schema("onda.signal@1 > onda.samples-info@1",
        recording::Union{UInt128,UUID} = UUID(recording),
        file_path::Any,
        file_format::AbstractString = file_format isa AbstractLPCMFormat ? file_format_string(file_format) : file_format,
        span::Union{NamedTupleTimeSpan,TimeSpan} = TimeSpan(span),
        kind::AbstractString = _validate_signal_kind(kind),
        channels::AbstractVector{<:AbstractString} = _validate_signal_channels(channels),
        sample_unit::AbstractString = _validate_signal_sample_unit(sample_unit))

function upgrade_row(from::SignalV1SchemaVersion, to::SignalV2SchemaVersion, row)
    # TODO
    return row
end

@deprecate validate(s) validate_samples(s.data, s.info, s.encoded) false
=#
