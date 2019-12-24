#####
##### `show` methods
#####

function Base.show(io::IO, w::TimeSpan)
    start_string = format_duration(first(w))
    stop_string = format_duration(last(w))
    return print(io, "TimeSpan(", start_string, ", ", stop_string, ')')
end

function Base.show(io::IO, samples::Samples)
    if get(io, :compact, false)
        print(io, "Samples(", summary(samples.data), ')')
    else
        duration_in_seconds = size(samples.data, 2) / samples.signal.sample_rate
        duration_in_nanoseconds = round(Int, duration_in_seconds * 1_000_000_000)
        println(io, "Samples (", format_duration(duration_in_nanoseconds), "):")
        println(io, "  signal.channel_names: ", channel_names_string(samples.signal.channel_names))
        println(io, "  signal.sample_unit: ", repr(samples.signal.sample_unit))
        println(io, "  signal.sample_resolution_in_unit: ", samples.signal.sample_resolution_in_unit)
        println(io, "  signal.sample_type: ", samples.signal.sample_type)
        println(io, "  signal.sample_rate: ", samples.signal.sample_rate, " Hz")
        println(io, "  signal.file_extension: ", repr(samples.signal.file_extension))
        println(io, "  signal.file_options: ", repr(samples.signal.file_options))
        println(io, "  encoded: ", samples.encoded)
        println(io, "  data:")
        show(io, "text/plain", samples.data)
    end
end

function Base.show(io::IO, signal::Signal)
    if get(io, :compact, false)
        print(io, "Signal(", channel_names_string(signal.channel_names), ")")
    else
        println(io, "Signal:")
        println(io, "  channel_names: ", channel_names_string(signal.channel_names))
        println(io, "  sample_unit: :", signal.sample_unit)
        println(io, "  sample_resolution_in_unit: ", signal.sample_resolution_in_unit)
        println(io, "  sample_type: ", signal.sample_type)
        println(io, "  sample_rate: ", signal.sample_rate, " Hz")
        println(io, "  file_extension: :", signal.file_extension)
        print(io,   "  file_options: ", repr(signal.file_options))
    end
end

function Base.show(io::IO, recording::Recording)
    if get(io, :compact, false)
        duration_string = format_duration(recording.duration_in_nanoseconds)
        print(io, "Recording(", duration_string, ')')
    else
        duration_in_seconds = recording.duration_in_nanoseconds.value / 1_000_000_000
        duration_string = string('(', format_duration(recording.duration_in_nanoseconds),
                                 "; ", duration_in_seconds, " seconds)")
        println(io, "Recording:")
        println(io, "  duration_in_nanoseconds: ", recording.duration_in_nanoseconds, " ", duration_string)
        println(io, "  signals:")
        compact_io = IOContext(io, :compact => true)
        for (name, signal) in recording.signals
            println(compact_io, "    :", name, " => ", signal)
        end
        println(io, "  annotations (", length(recording.annotations), " total):")
        annotation_counts = Dict()
        for ann in recording.annotations
            annotation_counts[ann.key] = get(annotation_counts, ann.key, 0) + 1
        end
        k = 1
        annotation_counts = sort(collect(annotation_counts), by=(p -> p[2]), lt=(>))
        for (x, n) in annotation_counts
            println(io, "    ", n, " instance(s) of ", x)
            k += 1
            if k > 5
                println(io, "    ...and ", length(annotation_counts) - 5, " more.")
                break
            end
        end
        print(io, "  custom:")
        if recording.custom isa Nothing
            print(io, " nothing")
        else
            println(io)
            show(io, "text/plain", recording.custom)
        end
    end
end

function Base.show(io::IO, dataset::Dataset)
    print(io, "Dataset(", dataset.path, ", ", length(dataset.recordings), " recordings)")
end

#####
##### utilities
#####

function channel_names_string(channel_names)
    return string('[', join(map(repr, channel_names), ", "), ']')
end

function nanosecond_to_periods(ns::Integer)
    μs, ns = divrem(ns, 1000)
    ms, μs = divrem(μs, 1000)
    s, ms = divrem(ms, 1000)
    m, s = divrem(s, 60)
    hr, m = divrem(m, 60)
    return (hr, m, s, ms, μs, ns)
end

format_duration(t::Period) =  format_duration(convert(Nanosecond, t).value)

function format_duration(ns::Integer)
    hr, m, s, ms, μs, ns = nanosecond_to_periods(ns)
    hr = lpad(hr, 2, '0')
    m = lpad(m, 2, '0')
    s = lpad(s, 2, '0')
    ms = lpad(ms, 3, '0')
    μs = lpad(μs, 3, '0')
    ns = lpad(ns, 3, '0')
    return string(hr, ':', m, ':', s, '.', ms, μs, ns)
end
