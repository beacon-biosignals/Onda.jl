#####
##### load/store
#####

"""
    load(signals_row[, timespan]; encoded::Bool=false)
    load(file_path, file_format::AbstractString, signal::Signal[, timespan]; encoded::Bool=false)
    load(file_path, file_format::AbstractLPCMFormat, signal::Signal[, timespan]; encoded::Bool=false)

Return the `Samples` object described by `signals_row`/`file_path`/`file_format`/`signal`.

If `timespan` is present, return `load(...)[:, timespan]`, but attempt to avoid reading
unreturned intermediate sample data. Note that the effectiveness of this optimized method
versus the naive approach depends on the types of `file_path` and `file_format`.

If `encoded` is `true`, do not decode the `Samples` object before returning it.
"""
function load(row, timespan...; encoded::Bool=false)
    return load(row.file_path, row.file_format, Signal(row), timespan...; encoded)
end

function load(file_path, file_format::AbstractString, signal::Signal, timespan...; encoded::Bool=false)
    return load(file_path, format(file_format, signal), signal, timespan...; encoded)
end

function load(file_path, file_format::AbstractLPCMFormat, signal::Signal; encoded::Bool=false)
    samples = Samples(read_lpcm(file_path, file_format), signal, true)
    return encoded ? samples : decode(samples)
end

function load(file_path, file_format::AbstractLPCMFormat, signal::Signal, timespan; encoded::Bool=false)
    sample_range = TimeSpans.index_from_time(signal.sample_rate, timespan)
    sample_offset, sample_count = first(sample_range) - 1, length(sample_range)
    sample_data = read_lpcm(file_path, file_format, sample_offset, sample_count)
    samples = Samples(sample_data, signal, true)
    return encoded ? samples : decode(samples)
end

"""
TODO
"""
function store(recording_uuid, file_path, file_format, samples::Samples; kwargs...)
    row = SignalsRow(samples.signal; recording_uuid, file_path, file_format)
    lpcm_format = file_format isa AbstractLPCMFormat ? file_format : format(file_format, signal; kwargs...)
    write_lpcm(file_path, encode(samples).data, lpcm_format)
    return row
end
