using Test, Onda, Dates, Random, UUIDs

@testset "pretty printing" begin
    @test repr(TimeSpan(6149872364198, 123412345678910)) == "TimeSpan(01:42:29.872364198, 34:16:52.345678910)"

    signal = Signal([:a, :b, Symbol("c-d")], :unit, 0.25, Int16, 50, :lpcm, Dict(:level => 4))
    @test sprint(show, signal, context=(:compact => true)) == "Signal([:a, :b, Symbol(\"c-d\")])"
    level = VERSION >= v"1.2" ? ":level => 4" : ":level=>4"
    @test sprint(show, signal) == """
                                  Signal:
                                    channel_names: [:a, :b, Symbol(\"c-d\")]
                                    sample_unit: :unit
                                    sample_resolution_in_unit: 0.25
                                    sample_type: Int16
                                    sample_rate: 50 Hz
                                    file_extension: :lpcm
                                    file_options: Dict{Symbol,Any}($level)"""

    samples = Samples(signal, true, rand(Random.MersenneTwister(0), signal.sample_type, 3, 5))
    @test sprint(show, samples, context=(:compact => true)) == "Samples(3×5 Array{Int16,2})"
    @test sprint(show, samples) == """
                                   Samples (00:00:00.100000000):
                                     signal.channel_names: [:a, :b, Symbol(\"c-d\")]
                                     signal.sample_unit: :unit
                                     signal.sample_resolution_in_unit: 0.25
                                     signal.sample_type: Int16
                                     signal.sample_rate: 50 Hz
                                     signal.file_extension: :lpcm
                                     signal.file_options: Dict{Symbol,Any}($level)
                                     encoded: true
                                     data:
                                   3×5 Array{Int16,2}:
                                    20032  4760  27427  -20758   24287
                                    14240  5037   5598   -5888   21784
                                    16885   600  20880  -32493  -19305"""
    annotations = Set(Annotation("key$i", "val", TimeSpan(0, 1)) for i in 1:10)
    recording = Recording(Nanosecond(100_000_000), Dict(:test => signal), annotations, nothing)
    recording_string = sprint(show, recording)
    @test startswith(recording_string, """
                                       Recording:
                                         duration_in_nanoseconds: 100000000 nanoseconds (00:00:00.100000000; 0.1 seconds)
                                         signals:
                                           :test => Signal([:a, :b, Symbol(\"c-d\")])
                                         annotations (10 total):""")
    @test endswith(recording_string, "...and 5 more.\n  custom: nothing")
    annotations = Set(reduce(vcat, [[Annotation("key$i", string(rand()), TimeSpan(0, 1)) for _ in 1:i] for i in 1:10]))
    recording = Recording(Nanosecond(100_000_000), Dict(:test => signal), annotations, Dict(:a => 1, :b => 2, :c => 2))
    @test sprint(show, recording) == """
                                     Recording:
                                       duration_in_nanoseconds: 100000000 nanoseconds (00:00:00.100000000; 0.1 seconds)
                                       signals:
                                         :test => Signal([:a, :b, Symbol(\"c-d\")])
                                       annotations (55 total):
                                         10 instance(s) of key10
                                         9 instance(s) of key9
                                         8 instance(s) of key8
                                         7 instance(s) of key7
                                         6 instance(s) of key6
                                         ...and 5 more.
                                       custom:
                                     Dict{Symbol,Int64} with 3 entries:
                                       :a => 1
                                       :b => 2
                                       :c => 2"""
    mktempdir() do root
        dataset = Dataset(joinpath(root, "test.onda"); create=true)
        @test sprint(show, dataset) == "Dataset($(dataset.path), 0 recordings)"
    end
end
