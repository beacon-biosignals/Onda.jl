# @deprecate validate(s) validate_samples(s.data, s.info, s.encoded) false

@testset "`onda.annotation` deprecations" begin
    possible_recordings = (uuid4(), uuid4(), uuid4())
    annotations = AnnotationV1[AnnotationV1(recording=rand(possible_recordings), id=uuid4(),
                                            span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))))
                               for i in 1:50]
    io = IOBuffer()
    write_annotations(io, annotations)
    @test read(seekstart(io)) == read(Legolas.tobuffer(annotations, AnnotationV1SchemaVersion()))
    @test_throws ErrorException Annotation(annotations[1])
end

@testset "`onda.signal` deprecations" begin
    possible_recordings = (uuid4(), uuid4(), uuid4())
    possible_sample_types = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64)
    signals = Onda.SignalV1[Onda.SignalV1(recording=rand(possible_recordings),
                                          file_path="x_$(i)_file",
                                          file_format=rand(("lpcm", "lpcm.zst")),
                                          span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
                                          kind="x_$i",
                                          channels=["a_$i", "b_$i", "c_$i"],
                                          sample_unit="unit_$i",
                                          sample_resolution_in_unit=rand((0.25, 1)),
                                          sample_offset_in_unit=rand((-0.25, 1)),
                                          sample_type=rand(possible_sample_types),
                                          sample_rate=rand((128, 50.5))) for i in 1:50]
    @test_throws ErrorException Signal(signals[1])
    for signal in signals
        @test Onda.upgrade(signal, SignalV2SchemaVersion()) isa SignalV2
    end
    signals2 = [Onda.upgrade(s, SignalV2SchemaVersion()) for s in signals]
    io = IOBuffer()
    write_signals(io, signals2)
    @test read(seekstart(io)) == read(Legolas.tobuffer(signals2, SignalV2SchemaVersion()))
    @test_throws ErrorException Signal(signals[1])
end

@testset "`Onda.Samples` deprecations" begin
    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c"],
                         sample_unit="unit",
                         sample_resolution_in_unit=0.25,
                         sample_offset_in_unit=-0.5,
                         sample_type=Int16,
                         sample_rate=50.2)
    data = rand(3, 10)
    samples = Onda.Samples(data, info, false)
    @test isnothing(Onda.validate(samples))
    samples = Onda.Samples(data, info, true; validate=false)
    @test_throws ArgumentError Onda.validate(samples)
    samples = encode(Onda.Samples(data, info, false))
    @test isnothing(Onda.validate(samples))
    samples = Onda.Samples(rand(4, 10), info, false; validate=false)
    @test_throws ArgumentError Onda.validate(samples)
    samples = Onda.Samples(rand(Int32, 4, 10), info, true; validate=false)
    @test_throws ArgumentError Onda.validate(samples)
end
