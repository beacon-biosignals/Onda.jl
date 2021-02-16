### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# ╔═╡ 34fdd5a2-7061-11eb-3898-9d78897eb2a9
using Onda, TimeSpans, DataFrames, Dates, UUIDs, Test, ConstructionBase

# ╔═╡ 4b479938-7061-11eb-01d9-0d7fe3a08ec4
using TimeSpans: duration, translate, start, stop, index_from_time, time_from_index

# ╔═╡ bc44d488-7062-11eb-1f44-75c2d606ed23
using PlutoUI

# ╔═╡ 90ffe862-7062-11eb-11c9-333c50eb4250
md"This file provides an introductory tour of Onda.jl by generating, storing,
and loading a toy Onda dataset. Run lines in the REPL to inspect output at
each step! Tests are littered throughout to demonstrate functionality in a
concrete manner, and so that we can ensure examples stay updated as the
package evolves.

NOTE: You should read <https://github.com/beacon-biosignals/OndaFormat>
before and/or alongside the completion of this tour; it explains the
purpose/structure of the format."

# ╔═╡ 7bf4f98a-7062-11eb-06c1-455620ceb265
md"# generate some mock data"

# ╔═╡ 82e4090c-7062-11eb-0eb5-e5f4143b05d8
md"""
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
Arrow tables and sample data files to a temporary directory."""

# ╔═╡ 4b9fd1ca-7061-11eb-1112-1fc36c7bca09
saws(info, duration) = [(j + i) % 100 * info.sample_resolution_in_unit for
                        i in 1:channel_count(info), j in 1:sample_count(info, duration)]

# ╔═╡ 4bb0e6c2-7061-11eb-0ea2-15404f93027f
root = mktempdir()

# ╔═╡ 4bc1fed0-7061-11eb-2c8f-79ece59340f8
signals_list = Signal[]

# ╔═╡ 4bd2f50a-7061-11eb-101c-355e365ce2b6
signals_recordings = [uuid4() for _ in 1:10]

# ╔═╡ 4be3ddfc-7061-11eb-3173-09256abd3f47
with_terminal() do # we'll use a PlutoUI terminal to view the logs
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
			push!(signals_list, signal)
		end
	end
end

# ╔═╡ 4bf4f77c-7061-11eb-3cc6-49926eb1ada2
path_to_signals_file = joinpath(root, "test.onda.signals.arrow")

# ╔═╡ 4c0639f6-7061-11eb-2b8a-c5e811c708b2
write_signals(path_to_signals_file, signals_list)

# ╔═╡ 4c16fb4c-7061-11eb-22cc-351fd7fa173f
with_terminal() do
	Onda.log("wrote out $path_to_signals_file")
end

# ╔═╡ 4c27cdf0-7061-11eb-2c90-938e53abe174
annotations_list = Annotation[]

# ╔═╡ 4c38c470-7061-11eb-0c1d-578cfedc3c02
sources = (uuid4(), uuid4(), uuid4())

# ╔═╡ 4c49d594-7061-11eb-3ec4-8fb053abd156
annotations_recordings = vcat(signals_recordings[1:end-1], uuid4()) # overlapping but not equal to signals_recordings

# ╔═╡ 4c5aebfe-7061-11eb-33ad-b194e5a93dff
for recording in annotations_recordings
    for i in 1:rand(3:10)
        start = Second(rand(0:60))
        annotation = Annotation(recording, uuid4(), TimeSpan(start, start + Second(rand(1:30)));
                                rating=rand(1:100), quality=rand(("good", "bad")), source=rand(sources))
        push!(annotations_list,  annotation)
    end
end

# ╔═╡ 4c6f4180-7061-11eb-2e33-8dd8d1db830d
path_to_annotations_file = joinpath(root, "test.onda.annotations.arrow")

# ╔═╡ 4c804e62-7061-11eb-0577-df59787ebec4
write_annotations(path_to_annotations_file, annotations_list)

# ╔═╡ 4c9141ea-7061-11eb-0dd7-fb12bcf78b87
with_terminal() do
	Onda.log("wrote out $path_to_annotations_file")
end

# ╔═╡ 6d666764-7062-11eb-04df-bdbdd7ba249c
md"# basic Onda + DataFrames patterns"

# ╔═╡ 638c79e0-7062-11eb-00d9-07e2f712f515
md"Since signals and annotations are represented tabularly, any package
that supports the Tables.jl interface can be used to interact with
them. Here, we show how you can use DataFrames.jl to perform a variety
of common operations.

Note that most of these operations are only shown here on a single table
to avoid redundancy, but these examples are generally applicable to both
signals and annotations tables.


Read Onda Arrow files into `DataFrame`s:"

# ╔═╡ 4ca22e1a-7061-11eb-0009-79be767a6ceb
signals = DataFrame(read_signals(path_to_signals_file))

# ╔═╡ 4cb31e14-7061-11eb-1c93-dd5d44dc97f5
annotations = DataFrame(read_annotations(path_to_annotations_file))

# ╔═╡ 5dfadd3c-7062-11eb-2a14-f5099c63a0f0
md"Grab all multichannel signals greater than 5 minutes long:"

# ╔═╡ 4cc40ee0-7061-11eb-299a-ff7517da04c8
filter(s -> length(s.channels) > 1 && duration(s.span) > Minute(5), signals)

# ╔═╡ 57c4fce8-7062-11eb-28b9-cf400d7a8fa7
md"Get all signals from a given recording:"

# ╔═╡ 4cd59aca-7061-11eb-08d3-7bc70d32a274
target = rand(signals.recording)

# ╔═╡ 4ce6b2b0-7061-11eb-075c-43f8a52cf9cd
view(signals, findall(==(target), signals.recording), :)

# ╔═╡ 4cf7a708-7061-11eb-1075-f732e0489c03
md"Group/index signals by recording:"

# ╔═╡ 4d108072-7061-11eb-22df-938117e1a9ab
grouped = groupby(signals, :recording)

# ╔═╡ 4d22f626-7061-11eb-0aad-5fa572357a04
grouped[(; recording=target)]

# ╔═╡ 4d3965c8-7061-11eb-3336-efdd186e0ed2
md"Group/index signals + annotations by recording together:"

# ╔═╡ 4d4a2e4e-7061-11eb-1c9b-1fd65063a538
dict = Onda.gather(:recording, signals, annotations)

# ╔═╡ 4d5b2032-7061-11eb-1919-399c94d2e6e2
dict[target]

# ╔═╡ 4b35c4a0-7062-11eb-0a45-97ebbca639c6
md"Count number of signals in each recording:"

# ╔═╡ 4d6c88fe-7061-11eb-02d2-d97ba5a6a764
combine(groupby(signals, :recording), nrow)

# ╔═╡ 45f83716-7062-11eb-2891-612638263a0b
md"Grab the longest signal in each recording:"

# ╔═╡ 4d7de90a-7061-11eb-28c9-17608cfd5b49
combine(s -> s[argmax(duration.(s.span)), :], groupby(signals, :recording))

# ╔═╡ 4d8ed9cc-7061-11eb-1343-e55d69ea9cba
md"Load all sample data for a given recording:"

# ╔═╡ 4da0918c-7061-11eb-0b35-65179ff145d3
transform(view(signals, findall(==(target), signals.recording), :),
          AsTable(:) => ByRow(load) => :samples)

# ╔═╡ 4db17bf8-7061-11eb-2049-638e5848bfdb
md"Delete all sample data for a given recording (uncomment the
inline-commented section to actual delete filtered signals'
sample data!):"

# ╔═╡ 4dc441fc-7061-11eb-178d-cb1d275a0933
signals_copy = copy(signals) # we're gonna keep using `signals` afterwards, so let's work with a copy

# ╔═╡ 4dd69956-7061-11eb-1e42-3b03338e0992
filter!(s -> s.recording != target #=|| (rm(s.file_path); false)=#, signals_copy)

# ╔═╡ 00ddbe44-7062-11eb-1146-5dde55f2496a
md"Merge overlapping annotations of the same `quality` in the same recording.
`merged` is an annotations table with a custom column of merged ids:"

# ╔═╡ 4de93106-7061-11eb-2f91-c381fe7358d6
merged = DataFrame(mapreduce(merge_overlapping_annotations, vcat, groupby(annotations, :quality)))

# ╔═╡ 2d571c26-7063-11eb-1e30-53bd264a2743
md"let's get the original annotation(s) from this merged annotation:"

# ╔═╡ 4dfbaf70-7061-11eb-3ee2-19623550b8b7
m = rand(eachrow(merged))

# ╔═╡ 4e122278-7061-11eb-1335-7d8c8d6a01a4
view(annotations, findall(in(m.from), annotations.id), :)

# ╔═╡ 281f5c18-7064-11eb-0f39-dfde823bee0f
md"Load all the annotated segments that fall within a given signal's timespan:"

# ╔═╡ 4e236380-7061-11eb-2c42-fb5003c4fe68
within_signal(ann, sig) = ann.recording == sig.recording && TimeSpans.contains(sig.span, ann.span)

# ╔═╡ 4e3453a0-7061-11eb-0f33-67ecb87e3ace
sig = first(sig for sig in eachrow(signals) if any(within_signal(ann, sig) for ann in eachrow(annotations)))

# ╔═╡ 4e4546e4-7061-11eb-3372-8102fe8f3be1
transform(filter(ann -> within_signal(ann, sig), annotations),
          :span => ByRow(span -> load(sig, translate(span, -start(sig.span)))) => :samples)

# ╔═╡ f3825c46-7061-11eb-1aae-332080b79e14
md"In the above, we called `load(sig, span)` for each `span`. This invocation attempts to load
*only* the sample data corresponding to `span`, which can be very efficient if the sample data
file format + storage system supports random access and the full sample data file is very large.
However, if random access isn't supported, or the sample data file is relatively small, or the
requested set of `span`s heavily overlap, this approach may be less efficient than simply loading
the whole file upfront. Here we demonstrate the latter as an alternative (note: in the future, we
want to support an optimal batch loader):"

# ╔═╡ 4e5a2bb0-7061-11eb-3606-0df313764c36
samples = load(sig)

# ╔═╡ 4e6b1a86-7061-11eb-14c7-1529f54013bd
transform(filter(ann -> within_signal(ann, sig), annotations),
          :span => ByRow(span -> view(samples, :, translate(span, -start(sig.span)))) => :samples)

# ╔═╡ e212354e-7061-11eb-15eb-6188c9f2e9d8
md" # working with `Samples`


A `Samples` struct wraps a matrix of interleaved LPCM-encoded (or decoded) sample data,
along with a `SamplesInfo` instance that allows this matrix to be encoded/decoded.
In this matrix, the rows correspond to channels and the columns correspond to timesteps.

Let's grab a `Samples` instance for one of our mock EEG signals:
"

# ╔═╡ 4e7c597c-7061-11eb-1f1a-5faf76511c5e
eeg_signal = signals[findfirst(==("eeg"), signals.kind), :]

# ╔═╡ 4e8d4b38-7061-11eb-0ede-c7f6e447d7f7
eeg = load(eeg_signal)

# ╔═╡ d841027a-7061-11eb-3485-9b93461baf91
md"Here are some basic functions for examining `Samples` instances:"

# ╔═╡ 4e9e1954-7061-11eb-3b95-b57411106fb7
@test eeg isa Samples && !eeg.encoded

# ╔═╡ 4eaf01ba-7061-11eb-096a-71446cf237ad
@test sample_count(eeg) == sample_count(eeg_signal, duration(eeg)) == index_from_time(eeg.info.sample_rate, duration(eeg)) - 1

# ╔═╡ 4ec06c02-7061-11eb-004a-79460361e3b2
@test channel_count(eeg) == channel_count(eeg_signal) == length(eeg.info.channels)

# ╔═╡ 4ed182ee-7061-11eb-32cf-91ee7fdaf180
@test channel(eeg, "f3") == channel(eeg_signal, "f3") == findfirst(==("f3"), eeg.info.channels)

# ╔═╡ 4ee26f28-7061-11eb-14f2-b7ae35af57b4
@test channel(eeg, 2) == channel(eeg_signal, 2) == eeg.info.channels[2]

# ╔═╡ 4ef3610c-7061-11eb-098a-29c85150e41f
@test duration(eeg) == duration(eeg_signal.span)

# ╔═╡ 0e89968c-7063-11eb-2c4b-ef59f6999987
md"Here are some basic indexing examples using `getindex` and `view` wherein
channel names and sample-rate-agnostic `TimeSpan`s are employed as indices:"

# ╔═╡ 4f058e18-7061-11eb-3af2-8b26d2fd02d6
span = TimeSpan(Second(3), Second(9))

# ╔═╡ 4f16f284-7061-11eb-0112-37c3353b5be7
span_range = index_from_time(eeg.info.sample_rate, span)

# ╔═╡ 4f2a9d16-7061-11eb-3c21-6fa13a98840b
@test eeg[:, span].data == view(eeg, :, span_range).data

# ╔═╡ 4f3b684e-7061-11eb-0968-c125752ca86f
@test eeg["f3", :].data == view(eeg, channel(eeg, "f3"), :).data

# ╔═╡ 4f4c56c2-7061-11eb-2128-557f0f0fa96c
@test eeg["f3", 1:10].data == view(eeg, channel(eeg, "f3"), 1:10).data

# ╔═╡ 4f6002da-7061-11eb-00d0-3509156a2deb
@test eeg["f3", span].data == view(eeg, channel(eeg, "f3"), span_range).data

# ╔═╡ 4f722a28-7061-11eb-2d0e-fd0b307d103a
rows_1 = ["f3", "c3", "p3"]

# ╔═╡ 4f845374-7061-11eb-2de1-f3cec6ce3a2d
@test eeg[rows_1, 1:10].data == view(eeg, channel.(Ref(eeg), rows_1), 1:10).data

# ╔═╡ 4f977046-7061-11eb-29ce-4dfe46c0cc0c
rows_2 = ["c3", 4, "f3"]

# ╔═╡ 4fa85b48-7061-11eb-0d7a-439626a1a3e1
@test eeg[rows_2, span].data == view(eeg, channel.(Ref(eeg), rows_2), span_range).data

# ╔═╡ 4fb9e2c6-7061-11eb-28d3-694cdac96eba
md"Note that `Samples` is not an `AbstractArray` subtype; the special indexing
behavior above is only defined for convenient data manipulation. It is fine
to access the sample data matrix directly via the `data` field if you need
to manipulate the matrix directly or pass it to downstream computations."

# ╔═╡ Cell order:
# ╟─90ffe862-7062-11eb-11c9-333c50eb4250
# ╠═34fdd5a2-7061-11eb-3898-9d78897eb2a9
# ╠═4b479938-7061-11eb-01d9-0d7fe3a08ec4
# ╠═bc44d488-7062-11eb-1f44-75c2d606ed23
# ╟─7bf4f98a-7062-11eb-06c1-455620ceb265
# ╟─82e4090c-7062-11eb-0eb5-e5f4143b05d8
# ╠═4b9fd1ca-7061-11eb-1112-1fc36c7bca09
# ╠═4bb0e6c2-7061-11eb-0ea2-15404f93027f
# ╠═4bc1fed0-7061-11eb-2c8f-79ece59340f8
# ╠═4bd2f50a-7061-11eb-101c-355e365ce2b6
# ╠═4be3ddfc-7061-11eb-3173-09256abd3f47
# ╠═4bf4f77c-7061-11eb-3cc6-49926eb1ada2
# ╠═4c0639f6-7061-11eb-2b8a-c5e811c708b2
# ╠═4c16fb4c-7061-11eb-22cc-351fd7fa173f
# ╠═4c27cdf0-7061-11eb-2c90-938e53abe174
# ╠═4c38c470-7061-11eb-0c1d-578cfedc3c02
# ╠═4c49d594-7061-11eb-3ec4-8fb053abd156
# ╠═4c5aebfe-7061-11eb-33ad-b194e5a93dff
# ╠═4c6f4180-7061-11eb-2e33-8dd8d1db830d
# ╠═4c804e62-7061-11eb-0577-df59787ebec4
# ╠═4c9141ea-7061-11eb-0dd7-fb12bcf78b87
# ╟─6d666764-7062-11eb-04df-bdbdd7ba249c
# ╟─638c79e0-7062-11eb-00d9-07e2f712f515
# ╠═4ca22e1a-7061-11eb-0009-79be767a6ceb
# ╠═4cb31e14-7061-11eb-1c93-dd5d44dc97f5
# ╟─5dfadd3c-7062-11eb-2a14-f5099c63a0f0
# ╠═4cc40ee0-7061-11eb-299a-ff7517da04c8
# ╟─57c4fce8-7062-11eb-28b9-cf400d7a8fa7
# ╠═4cd59aca-7061-11eb-08d3-7bc70d32a274
# ╠═4ce6b2b0-7061-11eb-075c-43f8a52cf9cd
# ╟─4cf7a708-7061-11eb-1075-f732e0489c03
# ╠═4d108072-7061-11eb-22df-938117e1a9ab
# ╠═4d22f626-7061-11eb-0aad-5fa572357a04
# ╟─4d3965c8-7061-11eb-3336-efdd186e0ed2
# ╠═4d4a2e4e-7061-11eb-1c9b-1fd65063a538
# ╠═4d5b2032-7061-11eb-1919-399c94d2e6e2
# ╟─4b35c4a0-7062-11eb-0a45-97ebbca639c6
# ╠═4d6c88fe-7061-11eb-02d2-d97ba5a6a764
# ╟─45f83716-7062-11eb-2891-612638263a0b
# ╠═4d7de90a-7061-11eb-28c9-17608cfd5b49
# ╟─4d8ed9cc-7061-11eb-1343-e55d69ea9cba
# ╠═4da0918c-7061-11eb-0b35-65179ff145d3
# ╟─4db17bf8-7061-11eb-2049-638e5848bfdb
# ╠═4dc441fc-7061-11eb-178d-cb1d275a0933
# ╠═4dd69956-7061-11eb-1e42-3b03338e0992
# ╟─00ddbe44-7062-11eb-1146-5dde55f2496a
# ╠═4de93106-7061-11eb-2f91-c381fe7358d6
# ╟─2d571c26-7063-11eb-1e30-53bd264a2743
# ╠═4dfbaf70-7061-11eb-3ee2-19623550b8b7
# ╠═4e122278-7061-11eb-1335-7d8c8d6a01a4
# ╟─281f5c18-7064-11eb-0f39-dfde823bee0f
# ╠═4e236380-7061-11eb-2c42-fb5003c4fe68
# ╠═4e3453a0-7061-11eb-0f33-67ecb87e3ace
# ╠═4e4546e4-7061-11eb-3372-8102fe8f3be1
# ╟─f3825c46-7061-11eb-1aae-332080b79e14
# ╠═4e5a2bb0-7061-11eb-3606-0df313764c36
# ╠═4e6b1a86-7061-11eb-14c7-1529f54013bd
# ╟─e212354e-7061-11eb-15eb-6188c9f2e9d8
# ╠═4e7c597c-7061-11eb-1f1a-5faf76511c5e
# ╠═4e8d4b38-7061-11eb-0ede-c7f6e447d7f7
# ╟─d841027a-7061-11eb-3485-9b93461baf91
# ╠═4e9e1954-7061-11eb-3b95-b57411106fb7
# ╠═4eaf01ba-7061-11eb-096a-71446cf237ad
# ╠═4ec06c02-7061-11eb-004a-79460361e3b2
# ╠═4ed182ee-7061-11eb-32cf-91ee7fdaf180
# ╠═4ee26f28-7061-11eb-14f2-b7ae35af57b4
# ╠═4ef3610c-7061-11eb-098a-29c85150e41f
# ╟─0e89968c-7063-11eb-2c4b-ef59f6999987
# ╠═4f058e18-7061-11eb-3af2-8b26d2fd02d6
# ╠═4f16f284-7061-11eb-0112-37c3353b5be7
# ╠═4f2a9d16-7061-11eb-3c21-6fa13a98840b
# ╠═4f3b684e-7061-11eb-0968-c125752ca86f
# ╠═4f4c56c2-7061-11eb-2128-557f0f0fa96c
# ╠═4f6002da-7061-11eb-00d0-3509156a2deb
# ╠═4f722a28-7061-11eb-2d0e-fd0b307d103a
# ╠═4f845374-7061-11eb-2de1-f3cec6ce3a2d
# ╠═4f977046-7061-11eb-29ce-4dfe46c0cc0c
# ╠═4fa85b48-7061-11eb-0d7a-439626a1a3e1
# ╟─4fb9e2c6-7061-11eb-28d3-694cdac96eba
