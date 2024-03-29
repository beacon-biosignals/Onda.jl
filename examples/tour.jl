# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.
#
# NOTE: You should read https://github.com/beacon-biosignals/Onda.jl/#the-onda-format-specification
# before and/or alongside the completion of this tour; it explains the
# purpose/structure of the format.
#
# NOTE: Onda.jl makes heavy use of Legolas.jl (https://github.com/beacon-biosignals/Legolas.jl).
# It is highly recommended to familiarize yourself with that package before embarking
# on this tour.

using Onda, Legolas, Arrow, TimeSpans, DataFrames, Dates, UUIDs, Test
using Legolas: @schema, @version

# We'll be kicking off this tour by generating some mock data to play with in subsequent sections!
#
# Before we dig in, keep in mind that Onda is primarily concerned with manipulating 3 interrelated entities.
# Paraphrasing from the Onda specification, these entities are:
#
# - "signals": A signal is the digitized output of a process, comprised of metadata (e.g. LPCM encoding,
#   channel information, sample data path/format information, etc.) and associated multi-channel sample
#   data.
#
# - "recordings": A recording is a collection of one or more signals recorded simultaneously over some
#   time period.
#
# - "annotations": An annotation is a a piece of (meta)data associated with a specific time span within
#   a specific recording.
#
# Signals and annotations are serialized as Arrow tables, while each sample data file is serialized to
# the file format specified by its corresponding signal's metadata. A "recording" is simply the collection
# of signals and annotations that share a common `recording` field, so we don't need to generate an actual
# table to represent recordings (though it can sometimes be useful to do so in practice!).

root = mktempdir()

#####
##### generate some mock signals
#####
# First, we generate a bunch of Onda signals across 10 recordings, writing the corresponding Arrow tables and
# sample data files to a temporary directory. Onda signals are represented via the Legolas-generated record
# type `SignalV2`, but are often initially constructed via `Onda`'s `store` method as seen below.

saw_waves(info, duration) = [(j + i) % 100 * info.sample_resolution_in_unit for
                             i in 1:channel_count(info), j in 1:sample_count(info, duration)]

signals = SignalV2[]
signals_recordings = [uuid4() for _ in 1:2]
for recording in signals_recordings
    for (sensor_type, file_format, channels) in (("eeg", "lpcm", ["fp1", "f3", "c3", "p3",
                                                                  "f7", "t3", "t5", "o1",
                                                                  "fz", "cz", "pz",
                                                                  "fp2", "f4", "c4", "p4",
                                                                  "f8", "t4", "t6", "o2"]),
                                                 ("ecg", "lpcm.zst", ["avl", "avr"]),
                                                 ("spo2", "lpcm", ["spo2"]))
        file_path = joinpath(root, string(recording, "_", sensor_type, ".", file_format))
        Onda.log("generating $file_path...")
        info = SamplesInfoV2(; sensor_type=sensor_type, channels=channels,
                             sample_unit="microvolt",
                             sample_resolution_in_unit=rand((0.25, 1)),
                             sample_offset_in_unit=rand((-1, 0, 1)),
                             sample_type=rand((Float32, Int16, Int32)),
                             sample_rate=rand((128, 256, 143.5)))
        data = saw_waves(info, Minute(rand(1:10)))
        samples = Samples(data, info, false)
        start = Second(rand(0:30))
        signal = store(file_path, file_format, samples, recording, start)
        signal::SignalV2 # we are returned a SignalV2 object from `store`
        push!(signals, signal)
    end
end
path_to_signals = joinpath(root, "test.onda.signal.arrow")
Legolas.write(path_to_signals, signals, SignalV2SchemaVersion())
Onda.log("wrote out $path_to_signals")

#####
##### generate some mock annotations
#####
# Next, let's generate some Onda annotations. Onda annotations are represented via the Legolas-generated
# record type `AnnotationV1`, but this record type only contains a few fields:
#
#   - `recording::UUID` (specifies the annotation's recording)
#   - `id::UUID` (the identifier of the annotation)
#   - `span::TimeSpan` (the relevant time span within the recording)
#
# These fields specify the particular region being annotated, but don't actually convey why the annotation
# exists in the first place. Thus, in practice, Onda annotation authors usually declare Legolas extensions
# that define additional fields on top of `AnnotationV1` that carry an annotation's associated metadata. For
# example:

@schema "example.my-annotation" MyAnnotation

@version MyAnnotationV1 > AnnotationV1 begin
    rating::Int
    quality::String
    source::UUID
end

annotations = MyAnnotationV1[]
sources = (uuid4(), uuid4(), uuid4())
annotations_recordings = vcat(signals_recordings[1:end-1], uuid4()) # overlapping but not equal to signals_recordings
for recording in annotations_recordings
    for i in 1:rand(3:10)
        start = Second(rand(0:60))
        annotation = MyAnnotationV1(; recording=recording, id=uuid4(), span=TimeSpan(start, start + Second(rand(1:30))),
                                    rating=rand(1:100), quality=rand(("good", "bad")), source=rand(sources))
        push!(annotations, annotation)
    end
end
path_to_annotations = joinpath(root, "test.onda.annotation.arrow")
Legolas.write(path_to_annotations, annotations, MyAnnotationV1SchemaVersion())
Onda.log("wrote out $path_to_annotations")

#####
##### basic Onda + DataFrames patterns
#####
# Since signals and annotations are represented tabularly, any package
# that supports the Tables.jl interface can be used to interact with
# them. Here, we show how you can use DataFrames.jl to perform a variety
# of common operations.
#
# If you're going to be working with Onda frequently, then it's probably
# worthwhile to become fluent in Julia's Tables.jl/DataFrames.jl
# ecosystem. This tour will give you a solid head start!
#
# Note that most of these operations are only shown here on a single table
# to avoid redundancy, but these examples are generally applicable to both
# signals and annotations tables.

# Read Onda Arrow files into `DataFrame`s:
signals = DataFrame(Legolas.read(path_to_signals))
annotations = DataFrame(Legolas.read(path_to_annotations))

# Get all signals from a given recording:
target = rand(signals.recording)
view(signals, findall(==(target), signals.recording), :)

# One of the consumer/producer-friendly properties of Onda is that signals
# and annotations are both represented in flat tables, enabling you to easily
# impose whatever indexing structure is most convenient for your use case.
#
# For example, if you wish to primarily access signals by `:recording` and `:sensor_type`,
# you can easily create a structure with that index via `groupby`:
target = rand(signals.recording)
grouped = groupby(signals, Cols(:recording, :sensor_type))
grouped[(target, "eeg")]

# Group/index signals + annotations by recording together:
target = rand(signals.recording)
dict = Legolas.gather(:recording, signals, annotations)
dict[target]

# Count number of signals in each recording:
combine(groupby(signals, :recording), nrow)

# Grab the longest signal in each recording:
combine(s -> s[argmax(duration.(s.span)), :], groupby(signals, :recording))

# Grab all multichannel signals greater than 5 minutes long:
filter(s -> length(s.channels) > 1 && duration(s.span) > Minute(5), signals)

# Load all sample data for a given recording:
target = rand(signals.recording)
transform(view(signals, findall(==(target), signals.recording), :),
          AsTable(:) => ByRow(load) => :samples)

# `mmap` sample data for a given LPCM signal:
target = first(s for s in eachrow(signals) if s.file_format == "lpcm")
Onda.mmap(target)

# Delete all sample data for a given recording (uncomment the
# inline-commented section to actual delete filtered signals'
# sample data!):
target = rand(signals.recording)
signals_copy = copy(signals) # we're gonna keep using `signals` afterwards, so let's work with a copy
filter!(s -> s.recording != target #=|| (rm(s.file_path); false)=#, signals_copy)

# Merge overlapping annotations of the same `quality` in the same recording.
# `merged` is an annotations table with a custom column of merged ids:
merged = DataFrame(mapreduce(merge_overlapping_annotations, vcat, groupby(annotations, :quality)))
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
# along with a `SamplesInfoV2` instance that allows this matrix to be encoded/decoded.
# In this matrix, the rows correspond to channels and the columns correspond to timesteps.

# Let's grab a `Samples` instance for one of our mock EEG signals:
eeg_signal = signals[findfirst(==("eeg"), signals.sensor_type), :]
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

# One can also index rows by regular expressions. For example, to match all the
# channels which have an `f`:
f_channels = ["fp1", "f3","f7", "fz", "fp2", "f4", "f8"]
@test eeg[r"f", span].data == view(eeg, channel.(Ref(eeg), f_channels), span_range).data

# Onda overloads the necessary Arrow.jl machinery to enable individual sample data
# segments (specifically, `Samples` and `SamplesInfoV2` values) to be (de)serialized
# to/from Arrow for storage or IPC purposes; see below for an example. Note that if
# you wanted to use Arrow as a storage format for whole sample data files w/ Onda,
# it'd make more sense to create an `AbstractLPCMFormat` subtype for your Arrow <-> LPCM
# mapping (an example of this can be seen in `examples/flac.jl`).
x = (a=[eeg], b=[eeg.info])
y = Arrow.Table(Arrow.tobuffer(x))
@test x.a == y.a
@test x.b == y.b

# Note that `Samples` is not an `AbstractArray` subtype; the special indexing
# behavior above is only defined for convenient data manipulation. It is fine
# to access the sample data matrix directly via the `data` field if you need
# to manipulate the matrix directly or pass it to downstream computations.
