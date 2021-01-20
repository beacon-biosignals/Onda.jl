# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.

# NOTE: You should read https://github.com/beacon-biosignals/OndaFormat
# before and/or alongside the completion of this tour; it explains the
# purpose/structure of the format.

using Onda, TimeSpans, DataFrames, Dates, UUIDs, Test, ConstructionBase
using Onda: Annotation, Signal, SamplesInfo, Samples, span, channel_count, sample_count
using TimeSpans: duration

#####
##### generate some mock data
#####
#=
Let's kick off the tour by generating some mock data to play with in subsequent sections!

Onda is primarily concerned with manipulating 3 interrelated entities. Paraphrasing from the
Onda specification, these entities are:

- "signals": A signal is the digitized output of a process, comprised of metadata (e.g. LPCM encoding,
  channel information, sample data path/format information, etc.) and associated multi-channel sample
  data.

- "recordings": A recording is a collection of one or more signals recorded simultaneously over some
  time period.

- "annotations": An annotation is a a piece of (meta)data associated with a specific time span within
  a specific recording.

Signals and annotations are serialized as Arrow tables, while each sample data file is serialized to
the file format specified by its corresponding signal's metadata. A "recording" is simply the collection
of signals and annotations that share a common `recording_uuid` field.

Below, we generate a bunch of signals/annotations across 10 recordings, writing the corresponding
Arrow tables and sample data files to a temporary directory.
=#

saws(info, duration) = [(j + i) % 100 * info.sample_resolution_in_unit for
                        i in 1:channel_count(info), j in 1:sample_count(info, duration)]

root = mktempdir()

signals = Signal{String}[]
signals_recording_uuids = [uuid4() for _ in 1:10]
for recording_uuid in signals_recording_uuids
    for (kind, channels) in ("eeg" => ["fp1", "f3", "c3", "p3",
                                       "f7", "t3", "t5", "o1",
                                       "fz", "cz", "pz",
                                       "fp2", "f4", "c4", "p4",
                                       "f8", "t4", "t6", "o2"],
                             "ecg" => ["avl", "avr"],
                             "spo2" => ["spo2"])
        file_format = rand(("lpcm", "lpcm.zst"))
        file_path = joinpath(root, string(recording_uuid, "_", kind, ".", file_format))
        Onda.log("generating $file_path...")
        info = SamplesInfo(; kind, channels,
                           sample_unit="microvolt",
                           sample_resolution_in_unit=rand((0.25, 1)),
                           sample_offset_in_unit=rand((-1, 0, 1)),
                           sample_type=rand((Float32, Int16, Int32)),
                           sample_rate=rand((128, 256, 143.5)))
        data = saws(info, Minute(rand(1:10)))
        samples = Samples(data, info, false)
        start = Minute(rand(0:10))
        signal = Onda.store(recording_uuid, file_path, file_format, start, samples)
        push!(signals, signal)
    end
end
path_to_signals_file = joinpath(root, "test.signals")
Onda.write_signals(path_to_signals_file, signals)
Onda.log("`*.signals` file written at $path_to_signals_file")

annotations = Annotation{NamedTuple{(:a, :b, :source),Tuple{Int64,String,UUID}}}[]
sources = (uuid4(), uuid4(), uuid4())
annotations_recording_uuids = vcat(signals_recording_uuids[1:end-1], uuid4()) # overlapping but not equal to signals_recording_uuids
for recording_uuid in annotations_recording_uuids
    for i in 1:rand(3:10)
        start = Second(rand(0:600))
        stop = start + Second(rand(1:30))
        annotation = Annotation(recording_uuid, uuid4(), start, stop,
                                (a=rand(1:100), b=rand(("good", "bad")), source=rand(sources)))
        push!(annotations,  annotation)
    end
end
path_to_annotations_file = joinpath(root, "test.annotations")
Onda.write_annotations(path_to_annotations_file, annotations)
Onda.log("`*.annotations` file written at $path_to_annotations_file")

#####
##### basic Onda + DataFrames patterns
#####
#=
Since signals and annotations are represented tabularly, any package
that supports the Tables.jl interface can be used to interact with
them. Here, we show how you can use DataFrames.jl to perform a variety
of common operations.

Note that most of these operations are only shown here on a single table
to avoid redundancy, but these examples are generally applicable to both
signals and annotations tables.
=#

# read Onda Arrow files into `DataFrame`s
signals = DataFrame(Onda.read_signals(path_to_signals_file))
annotations = DataFrame(Onda.read_annotations(path_to_annotations_file))

# grab all multichannel signals greater than 5 minutes long
filter(s -> length(s.channels) > 1 && duration(span(s)) > Minute(5), signals)

# get signal by recording_uuid
target_uuid = rand(signals.recording_uuid)
view(signals, findall(==(target_uuid), signals.recording_uuid), :)

# group/index signals by recording_uuid
target_uuid = rand(signals.recording_uuid)
grouped = groupby(signals, :recording_uuid)
grouped[(; recording_uuid=target_uuid)]

# group/index signals + annotations by recording_uuid
Onda.by_recording(signals, annotations)

# count number of signals in each recording
combine(groupby(signals, :recording_uuid), nrow)

# grab the longest signal in each recording
combine(s -> s[argmax(duration.(span.(eachrow(s)))), :], groupby(signals, :recording_uuid))

# load all sample data for a given recording
target_uuid = rand(signals.recording_uuid)
target_signals = view(signals, findall(==(target_uuid), signals.recording_uuid), :)
Onda.load.(eachrow(target_signals))

# delete all sample data for a given recording (uncomment the
# inline-commented section to actual delete filtered signals'
# sample data!)
target_uuid = rand(signals.recording_uuid)
signals_copy = copy(signals) # we're gonna keep using `signals` afterwards, so let's work with a copy
filter!(s -> s.recording_uuid != target_uuid #=|| (rm(s.file_path); false)=#, signals_copy)

#####
##### working with `Samples`
#####

# TODO