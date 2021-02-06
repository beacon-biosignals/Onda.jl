# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.

# NOTE: You should read https://github.com/beacon-biosignals/OndaFormat
# before and/or alongside the completion of this tour; it explains the
# purpose/structure of the format.

using Onda, TimeSpans, DataFrames, Dates, UUIDs, Test, ConstructionBase
using Onda: Annotation, Signal, SamplesInfo, Samples, channel_count, sample_count
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
of signals and annotations that share a common `recording` field.

Below, we generate a bunch of signals/annotations across 10 recordings, writing the corresponding
Arrow tables and sample data files to a temporary directory.
=#

saws(info, duration) = [(j + i) % 100 * info.sample_resolution_in_unit for
                        i in 1:channel_count(info), j in 1:sample_count(info, duration)]

root = mktempdir()

signals = Signal[]
signals_recordings = [uuid4() for _ in 1:10]
for recording in signals_recordings
    for (kind, channels) in ("eeg" => ["fp1", "f3", "c3", "p3",
                                       "f7", "t3", "t5", "o1",
                                       "fz", "cz", "pz",
                                       "fp2", "f4", "c4", "p4",
                                       "f8", "t4", "t6", "o2"],
                             "ecg" => ["avl", "avr"],
                             "spo2" => ["spo2"])
        file_format = rand(("lpcm", "lpcm.zst"))
        file_path = joinpath(root, string(recording, "_", kind, ".", file_format))
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
        signal = Onda.store(recording, file_path, file_format, start, samples)
        push!(signals, signal)
    end
end
path_to_signals_file = joinpath(root, "test.signals")
Onda.write_signals(path_to_signals_file, signals)
Onda.log("`*.signals` file written at $path_to_signals_file")

annotations = Annotation[]
sources = (uuid4(), uuid4(), uuid4())
annotations_recordings = vcat(signals_recordings[1:end-1], uuid4()) # overlapping but not equal to signals_recordings
for recording in annotations_recordings
    for i in 1:rand(3:10)
        start = Second(rand(0:30))
        annotation = Annotation(recording, uuid4(), TimeSpan(start, start + Second(rand(1:30)));
                                rating=rand(1:100), quality=rand(("good", "bad")), source=rand(sources))
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
filter(s -> length(s.channels) > 1 && duration(s.span) > Minute(5), signals)

# get signal by recording
target = rand(signals.recording)
view(signals, findall(==(target), signals.recording), :)

# group/index signals by recording
target = rand(signals.recording)
grouped = groupby(signals, :recording)
grouped[(; recording=target)]

# group/index signals + annotations by recording together
target = rand(signals.recording)
dict = Onda.gather(:recording, signals, annotations)
dict[target]

# count number of signals in each recording
combine(groupby(signals, :recording), nrow)

# grab the longest signal in each recording
combine(s -> s[argmax(duration.(s.span)), :], groupby(signals, :recording))

# load all sample data for a given recording
target = rand(signals.recording)
transform(view(signals, findall(==(target), signals.recording), :),
          AsTable(:) => ByRow(Onda.load) => :samples)

# delete all sample data for a given recording (uncomment the
# inline-commented section to actual delete filtered signals'
# sample data!)
target = rand(signals.recording)
signals_copy = copy(signals) # we're gonna keep using `signals` afterwards, so let's work with a copy
filter!(s -> s.recording != target #=|| (rm(s.file_path); false)=#, signals_copy)

# merge overlapping annotations of the same `quality` in the same recording.
# `merged` is an annotations table with a custom column of merged ids.
merged = DataFrame(mapreduce(Onda.merge_overlapping, vcat, groupby(annotations, [:recording, :quality])))
m = rand(eachrow(merged)) # let's get the original annotation(s) from this merged annotation
view(annotations, findall(in(m.from), annotations.id), :)

# load all the annotated segments that fall within a given signal's timespan
within_signal(ann, sig) = ann.recording == sig.recording && TimeSpans.contains(sig.span, ann.span)
sig = first(sig for sig in eachrow(signals) if any(within_signal(ann, sig) for ann in eachrow(annotations)))
transform(filter(ann -> within_signal(ann, sig), annotations),
          :span => (span -> Onda.load.(Ref(signal), span)) => :samples)

#####
##### working with `Samples`
#####

# TODO
