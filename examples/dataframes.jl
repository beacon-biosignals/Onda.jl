#####
##### basic Onda + DataFrames patterns
#####

using Onda, DataFrames
using Onda: span
using TimeSpans: duration

# load `*.signals` file into `DataFrame`
signals = DataFrame(Onda.read_signals(joinpath(root, "onda.signals")))

# grab all multichannel signals greater than 30 minutes long
filter(r -> length(r.channels) > 1 && duration(span(r)) > Minute(30), signals)

# index signals by recording_uuid
Dict(k.recording_uuid => s for (k, s) in pairs(groupby(signals, :recording_uuid)))

# count number of signals in each recording
combine(groupby(signals, :recording_uuid), nrow)
