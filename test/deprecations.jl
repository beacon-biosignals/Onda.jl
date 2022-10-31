@testset "onda.annotation deprecations" begin
    root = mktempdir()
    possible_recordings = (uuid4(), uuid4(), uuid4())
    annotations = Annotation[Annotation(recording=rand(possible_recordings),
                                        id=uuid4(),
                                        span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
                                        a=randstring('a':'z', 10),
                                        b=rand(Int, 1),
                                        c=rand(3)) for i in 1:50]
    annotations_file_path_1 = joinpath(root, "test-1.onda.annotations.arrow")
    annotations_file_path_2 = joinpath(root, "test-2.onda.annotations.arrow")
    cols = Tables.columns(annotations)
    io = IOBuffer()
    write_annotations(annotations_file_path_1, cols)
    Arrow.write(annotations_file_path_2, cols)
    write_annotations(io, cols)
    seekstart(io)
    for roundtripped in (read_annotations(annotations_file_path_1; validate_schema=false),
                         read_annotations(annotations_file_path_1; validate_schema=true),
                         read_annotations(annotations_file_path_2; validate_schema=false),
                         read_annotations(annotations_file_path_2; validate_schema=true),
                         Onda.materialize(read_annotations(io)),
                         read_annotations(seekstart(io); validate_schema=true))
        roundtripped = collect(Tables.rows(roundtripped))
        @test length(roundtripped) == length(annotations)
        for (r, a) in zip(roundtripped, annotations)
            @test NamedTuple(a) == NamedTuple(r)
            @test NamedTuple(a) == NamedTuple(Annotation(r))
        end
    end
    x = first(annotations)
    y = @compat Annotation(x.recording, x.id, x.span; x.a, x.b, x.c)
    @test x == y
    @test (@test_deprecated setproperties(y; a='+')) == Annotation(rowmerge(y; a='+'))
    df = DataFrame(annotations)
    @test Onda.gather(:recording, df) == Legolas.gather(:recording, df)

    names = (:recording, :id, :span)
    types = Tuple{Union{UInt128,UUID},Union{UInt128,UUID},Union{Onda.NamedTupleTimeSpan,TimeSpan}}
    @test (@test_deprecated Onda.validate_annotation_schema(nothing)) === nothing
    @test (@test_deprecated Onda.validate_annotation_schema(Tables.Schema(names, types))) === nothing
    @test_throws ArgumentError Onda.validate_annotation_schema(Tables.Schema((:x, :y), (Any, Any)))
end

@testset "onda.signal deprecations" begin
    root = mktempdir()
    possible_recordings = (uuid4(), uuid4(), uuid4())
    possible_sample_types = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64)
    signals = Signal[Signal(recording=rand(possible_recordings),
                            file_path=joinpath(root, "x_$(i)_file"),
                            file_format=rand(("lpcm", "lpcm.zst")),
                            span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
                            kind="x_$i",
                            channels=["a_$i", "b_$i", "c_$i"],
                            sample_unit="unit_$i",
                            sample_resolution_in_unit=rand((0.25, 1)),
                            sample_offset_in_unit=rand((-0.25, 0.25)),
                            sample_type=rand(possible_sample_types),
                            sample_rate=rand((128, 50.5)),
                            a=join(rand('a':'z', 10)),
                            b=rand(Int, 1),
                            c=rand(3)) for i in 1:50]
    signals_file_path_1 = joinpath(root, "test-1.onda.signals.arrow")
    signals_file_path_2 = joinpath(root, "test-2.onda.signals.arrow")
    io = IOBuffer()
    write_signals(signals_file_path_1, signals)
    Arrow.write(signals_file_path_2, signals)
    write_signals(io, signals)
    seekstart(io)
    io2 = IOBuffer()
    write_signals(io2, signals; file=false)
    seekstart(io2)
    for roundtripped in (read_signals(signals_file_path_1; validate_schema=false),
                         read_signals(signals_file_path_1; validate_schema=true),
                         read_signals(signals_file_path_2; validate_schema=false),
                         read_signals(signals_file_path_2; validate_schema=true),
                         (tmp=read_signals(io); @test_deprecated Onda.materialize(tmp)),
                         (tmp=read_signals(io2); @test_deprecated Onda.materialize(tmp)),
                         read_signals(seekstart(io); validate_schema=true))
        roundtripped = collect(Tables.rows(roundtripped))
        @test length(roundtripped) == length(signals)
        for (r, s) in zip(roundtripped, signals)
            @test NamedTuple(s) == NamedTuple(r)
            @test NamedTuple(s) == NamedTuple(Signal(r))
        end
    end
    x = first(signals)
    y = @compat Signal(x.recording, x.file_path, x.file_format, x.span, x.kind, x.channels, x.sample_unit,
                       x.sample_resolution_in_unit, x.sample_offset_in_unit, x.sample_type, x.sample_rate;
                       x.a, x.b, x.c)
    @test x == y
    x = Onda.extract_samples_info(x)
    z = @test_deprecated (@compat Signal(x; y.recording, y.file_path, y.file_format, y.span, y.a, y.b, y.c))
    @test y == z
    @test (@test_deprecated setproperties(z; sample_rate=1.0)) == Signal(rowmerge(z; sample_rate=1.0))
    y = SamplesInfo(x.kind, x.channels, x.sample_unit, x.sample_resolution_in_unit, x.sample_offset_in_unit, x.sample_type, x.sample_rate)
    @test x == y
    @test (@test_deprecated setproperties(y; sample_rate=1.0)) == SamplesInfo(rowmerge(y; sample_rate=1.0))
    @test isnothing(@test_deprecated Onda.validate_samples(y))
    df = DataFrame(signals)
    @test (@test_deprecated Onda.gather(:recording, df)) == Legolas.gather(:recording, df)

    names = (:recording, :file_path, :file_format, :span, :kind, :channels, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate)
    types = Tuple{Union{UInt128,UUID},Any,AbstractString,Union{Onda.NamedTupleTimeSpan,TimeSpan},AbstractString,AbstractVector{<:AbstractString},AbstractString,
                  Onda.LPCM_SAMPLE_TYPE_UNION,Onda.LPCM_SAMPLE_TYPE_UNION,AbstractString,Onda.LPCM_SAMPLE_TYPE_UNION}
    @test (@test_deprecated Onda.validate_signal_schema(nothing)) === nothing
    @test (@test_deprecated Onda.validate_signal_schema(Tables.Schema(names, types))) === nothing
    @test_throws ArgumentError Onda.validate_signal_schema(Tables.Schema((:x, :y), (Any, Any)))
end
