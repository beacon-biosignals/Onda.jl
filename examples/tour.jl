# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.

# NOTE: It's helpful to read https://github.com/beacon-biosignals/OndaFormat
# before and/or alongside the completion of this tour.

using Onda, TimeSpans, DataFrames, Dates, UUIDs, Test, ConstructionBase
using Onda: SignalsRow, span
using TimeSpans: duration

#####
##### generate mock data
#####

root = mktempdir()
signals = SignalsRow{String}[]
for recording_uuid in (uuid4() for _ in 1:10)
    for (kind, channels) in ("eeg" => ["fp1", "f3", "c3", "p3",
                                       "f7", "t3", "t5", "o1",
                                       "fz", "cz", "pz",
                                       "fp2", "f4", "c4", "p4",
                                       "f8", "t4", "t6", "o2"],
                             "ecg" => ["avl", "avr"],
                             "spo2" => ["spo2"])
        start_nanosecond = Nanosecond(Minute(rand(0:10)))
        stop_nanosecond = start_nanosecond + Nanosecond(Minute(rand(0:10)))
        file_format = rand(("lpcm", "lpcm.zst"))
        push!(signals, SignalsRow(; recording_uuid,
                                  file_path=joinpath(root, string(recording_uuid, "_", kind, ".", file_format)),
                                  file_format,
                                  start_nanosecond,
                                  stop_nanosecond,
                                  kind, channels,
                                  sample_unit="microvolt",
                                  sample_resolution_in_unit=rand((0.25, 1)),
                                  sample_offset_in_unit=rand((-1, 0, 1)),
                                  sample_type=rand((Float32, Int16, Int32)),
                                  sample_rate=rand((128, 256, 143.5))))
    end
end

#####
##### basic Onda + DataFrames patterns
#####

# load a `*.signals` file into `DataFrame`
signals = DataFrame(Onda.read_signals(PATH_TO_SIGNALS_FILE))

# grab all multichannel signals greater than 5 minutes long
filter(s -> length(s.channels) > 1 && duration(span(s)) > Minute(5), signals)

# index signals by recording_uuid
Dict(k.recording_uuid => s for (k, s) in pairs(groupby(signals, :recording_uuid)))

# count number of signals in each recording
combine(groupby(signals, :recording_uuid), nrow)

# grab the longest signal in each recording
combine(s -> s[argmax(duration.(span.(eachrow(s)))), :], groupby(signals, :recording_uuid))

# remove a recording from the dataset
filter!(s -> s.recording_uuid == target_uuid && (rm(s.file_path); true), signals)

