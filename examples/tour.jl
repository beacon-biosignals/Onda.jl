# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.

# NOTE: You should read https://github.com/beacon-biosignals/OndaFormat
# before and/or alongside the completion of this tour; it explains the
# purpose/structure of the format.

using Onda, TimeSpans, DataFrames, Dates, UUIDs, Test, ConstructionBase
using TimeSpans: duration, translate, start, stop, index_from_time, time_from_index

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
        start = Second(rand(0:30))
        signal = store(file_path, file_format, samples, recording, start)
        push!(signals, signal)
    end
end
path_to_signals_file = joinpath(root, "test.onda.signals.arrow")
write_signals(path_to_signals_file, signals)
Onda.log("`*.signals` file written at $path_to_signals_file")

annotations = Annotation[]
sources = (uuid4(), uuid4(), uuid4())
annotations_recordings = vcat(signals_recordings[1:end-1], uuid4()) # overlapping but not equal to signals_recordings
for recording in annotations_recordings
    for i in 1:rand(3:10)
        start = Second(rand(0:60))
        annotation = Annotation(recording, uuid4(), TimeSpan(start, start + Second(rand(1:30)));
                                rating=rand(1:100), quality=rand(("good", "bad")), source=rand(sources))
        push!(annotations,  annotation)
    end
end
path_to_annotations_file = joinpath(root, "test.onda.annotations.arrow")
write_annotations(path_to_annotations_file, annotations)
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

# Read Onda Arrow files into `DataFrame`s:
signals = DataFrame(read_signals(path_to_signals_file))
annotations = DataFrame(read_annotations(path_to_annotations_file))

# Grab all multichannel signals greater than 5 minutes long:
filter(s -> length(s.channels) > 1 && duration(s.span) > Minute(5), signals)

# Get all signals from a given recording:
target = rand(signals.recording)
view(signals, findall(==(target), signals.recording), :)

# Group/index signals by recording:
target = rand(signals.recording)
grouped = groupby(signals, :recording)
grouped[(; recording=target)]

# Group/index signals + annotations by recording together:
target = rand(signals.recording)
dict = Onda.gather(:recording, signals, annotations)
dict[target]

# Count number of signals in each recording:
combine(groupby(signals, :recording), nrow)

# Grab the longest signal in each recording:
combine(s -> s[argmax(duration.(s.span)), :], groupby(signals, :recording))

# Load all sample data for a given recording:
target = rand(signals.recording)
transform(view(signals, findall(==(target), signals.recording), :),
          AsTable(:) => ByRow(load) => :samples)

# Delete all sample data for a given recording (uncomment the
# inline-commented section to actual delete filtered signals'
# sample data!):
target = rand(signals.recording)
signals_copy = copy(signals) # we're gonna keep using `signals` afterwards, so let's work with a copy
filter!(s -> s.recording != target #=|| (rm(s.file_path); false)=#, signals_copy)

# Merge overlapping annotations of the same `quality` in the same recording.
# `merged` is an annotations table with a custom column of merged ids:
merged = DataFrame(mapreduce(merge_overlapping_annotations, vcat, groupby(annotations, [:recording, :quality])))
m = rand(eachrow(merged)) # let's get the original annotation(s) from this merged annotation
view(annotations, findall(in(m.from), annotations.id), :)

# Load all the annotated segments that fall within a given signal's timespan:
within_signal(ann, sig) = ann.recording == sig.recording && TimeSpans.contains(sig.span, ann.span)
sig = first(sig for sig in eachrow(signals) if any(within_signal(ann, sig) for ann in eachrow(annotations)))
transform(filter(ann -> within_signal(ann, sig), annotations),
          :span => ByRow(span -> load(sig, translate(span, -start(sig.span)))) => :samples)

# In the above, we called `load(sig, span)` for each `span`. This invocation attempts to load
# *only* the sample data corresponding to `span`, which can be very efficient if the sample data
# file format + storage system supports random access and the full sample data file is very large.
# However, if random access isn't supported, or the sample data file is relatively small, or the
# requested set of `span`s heavily overlap, this approach may be less efficient than simply loading
# the whole file upfront. Here we demonstrate the latter as an alternative (note: in the future, we
# want to support an optimal batch loader):
samples = load(sig)
transform(filter(ann -> within_signal(ann, sig), annotations),
          :span => ByRow(span -> view(samples, :, translate(span, -start(sig.span)))) => :samples)

#####
##### working with `Samples`
#####
# A `Samples` struct wraps a matrix of interleaved LPCM-encoded (or decoded) sample data,
# along with a `SamplesInfo` instance that allows this matrix to be encoded/decoded.
# In this matrix, the rows correspond to channels and the columns correspond to timesteps.

# Let's grab a `Samples` instance for one of our mock EEG signals:
eeg_signal = signals[findfirst(==("eeg"), signals.kind), :]
eeg = load(eeg_signal)

# # Here are some basic functions for examining `Samples` instances:
@test eeg isa Samples && !eeg.encoded
@test sample_count(eeg) == sample_count(eeg_signal, duration(eeg)) == index_from_time(eeg.info.sample_rate, duration(eeg)) - 1
@test channel_count(eeg) == channel_count(eeg_signal) == length(eeg.info.channels)
@test channel(eeg, "f3") == channel(eeg_signal, "f3") == findfirst(==("f3"), eeg.info.channels)
@test channel(eeg, 2) == channel(eeg_signal, 2) == eeg.info.channels[2]
@test duration(eeg) == duration(eeg_signal.span)

# Here are some basic indexing examples using `getindex` and `view` wherein
# channel names and sample-rate-agnostic `TimeSpan`s are employed as indices:
span = TimeSpan(Second(3), Second(9))
span_range = index_from_time(eeg.info.sample_rate, span)
@test eeg[:, span].data == view(eeg, :, span_range).data
@test eeg["f3", :].data == view(eeg, channel(eeg, "f3"), :).data
@test eeg["f3", 1:10].data == view(eeg, channel(eeg, "f3"), 1:10).data
@test eeg["f3", span].data == view(eeg, channel(eeg, "f3"), span_range).data
rows = ["f3", "c3", "p3"]
@test eeg[rows, 1:10].data == view(eeg, channel.(Ref(eeg), rows), 1:10).data
rows = ["c3", 4, "f3"]
@test eeg[rows, span].data == view(eeg, channel.(Ref(eeg), rows), span_range).data

# Note that `Samples` is not an `AbstractArray` subtype; the special indexing
# behavior above is only defined for convenient data manipulation. It is fine
# to access the sample data matrix directly via the `data` field if you need
# to manipulate the matrix directly or pass it to downstream computations.
