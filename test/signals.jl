@testset "`julia_type_from_onda_sample_type`/`onda_sample_type_from_julia_type`" begin
    @test Onda.julia_type_from_onda_sample_type("int8") === Int8
    @test Onda.julia_type_from_onda_sample_type("int16") === Int16
    @test Onda.julia_type_from_onda_sample_type("int32") === Int32
    @test Onda.julia_type_from_onda_sample_type("int64") === Int64
    @test Onda.julia_type_from_onda_sample_type("uint8") === UInt8
    @test Onda.julia_type_from_onda_sample_type("uint16") === UInt16
    @test Onda.julia_type_from_onda_sample_type("uint32") === UInt32
    @test Onda.julia_type_from_onda_sample_type("uint64") === UInt64
    @test Onda.julia_type_from_onda_sample_type("float32") === Float32
    @test Onda.julia_type_from_onda_sample_type("float64") === Float64
    @test_throws ArgumentError Onda.julia_type_from_onda_sample_type("bob")
    @test Onda.onda_sample_type_from_julia_type(Int8) === "int8"
    @test Onda.onda_sample_type_from_julia_type(Int16) === "int16"
    @test Onda.onda_sample_type_from_julia_type(Int32) === "int32"
    @test Onda.onda_sample_type_from_julia_type(Int64) === "int64"
    @test Onda.onda_sample_type_from_julia_type(UInt8) === "uint8"
    @test Onda.onda_sample_type_from_julia_type(UInt16) === "uint16"
    @test Onda.onda_sample_type_from_julia_type(UInt32) === "uint32"
    @test Onda.onda_sample_type_from_julia_type(UInt64) === "uint64"
    @test Onda.onda_sample_type_from_julia_type(Float32) === "float32"
    @test Onda.onda_sample_type_from_julia_type(Float64) === "float64"
    @test_throws ArgumentError Onda.onda_sample_type_from_julia_type(String)
end

function test_signal_field_types(signal::Signal)
    @test signal.recording isa UUID
    @test signal.file_format isa String
    @test signal.span isa TimeSpan
    @test signal.kind isa String
    @test signal.channels isa Vector{String}
    @test signal.sample_unit isa String
    @test signal.sample_resolution_in_unit isa Onda.LPCM_SAMPLE_TYPE_UNION
    @test signal.sample_offset_in_unit isa Onda.LPCM_SAMPLE_TYPE_UNION
    @test signal.sample_type isa String
    @test Onda.julia_type_from_onda_sample_type(signal.sample_type) isa DataType
    @test signal.sample_rate isa Onda.LPCM_SAMPLE_TYPE_UNION
    return signal
end

function test_signal_row(recording, file_path, file_format, span, kind, channels, sample_unit,
                         sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate;
                         custom...)
    row = (; recording, file_path, file_format, span, kind, channels, sample_unit,
           sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate)
    row_with_custom = (; row..., custom...)

    # intended normalization of input fields for constructor
    recording::UUID = recording isa UUID ? recording : UUID(recording)
    file_format::String = file_format isa AbstractLPCMFormat ? Onda.file_format_string(file_format) : file_format
    span::TimeSpan = TimeSpan(span)
    kind::String = kind
    channels::Vector{String} = channels
    sample_unit::String = sample_unit
    sample_type::String = sample_type isa DataType ? Onda.onda_sample_type_from_julia_type(sample_type) : sample_type
    norm_row = (; recording, file_path, file_format, span, kind, channels, sample_unit,
                sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate)
    norm_row_with_custom = (; norm_row..., custom...)

    @test has_rows(test_signal_field_types(Signal(row)), norm_row)
    @test has_rows(test_signal_field_types(Signal(row_with_custom)), norm_row_with_custom)
    @test has_rows(test_signal_field_types(Signal(Signal(row))), norm_row)
    @test has_rows(test_signal_field_types(Signal(Signal(row_with_custom))), norm_row_with_custom)
    @test has_rows(test_signal_field_types(Signal(Tables.Row(row))), norm_row)
    @test has_rows(test_signal_field_types(Signal(Tables.Row(row_with_custom))), norm_row_with_custom)
    @test has_rows(test_signal_field_types(Signal(row...)), norm_row)
    @test has_rows(test_signal_field_types(Signal(; row...)), norm_row)
    @test has_rows(test_signal_field_types(Signal(row...; custom...)), norm_row_with_custom)
    @test has_rows(test_signal_field_types(Signal(; row..., custom...)), norm_row_with_custom)
end

@testset "`Signal` construction/access" begin
    custom = (a="test", b=1, c=[2.0, 3.0])
    test_signal_row(UInt128(uuid4()), "/file/path", "lpcm", (start=Nanosecond(1), stop=Nanosecond(100)),
                    "kind", view([SubString("abc", 1:2), "a", "c"], :), "microvolt", 1, 0, "uint16",
                    256; custom...)
    test_signal_row(uuid4(), "/file/path", "lpcm", TimeSpan(Nanosecond(1), Nanosecond(100)),
                    "kind", ["ab", "a", "c"], "microvolt", 1.5, 0.4, UInt16, 256.3; custom...)
    test_signal_row(UInt128(uuid4()), "/file/path", LPCMFormat(3, UInt16), (start=Nanosecond(1), stop=Nanosecond(100)),
                    "kind", view([SubString("abc", 1:2), "a", "c"], :), "microvolt", 1, 0, "uint16",
                    256; custom...)
    test_signal_row(uuid4(), "/file/path", LPCMZstFormat(LPCMFormat(3, UInt16)), TimeSpan(Nanosecond(1), Nanosecond(100)),
                    "kind", ["ab", "a", "c"], "microvolt", 1.5, 0.4, UInt16, 256.3; custom...)
end

@testset "`read_signals`/`write_signals`" begin
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
    signals_file_path = joinpath(root, "test.onda.signals.arrow")
    io = IOBuffer()
    write_signals(signals_file_path, signals)
    write_signals(io, signals)
    seekstart(io)
    for roundtripped in (read_signals(signals_file_path; materialize=false, validate_schema=false),
                         read_signals(signals_file_path; materialize=true, validate_schema=true),
                         Onda.materialize(read_signals(io; validate_schema=true))
                         read_signals(io; validate_schema=true))
        roundtripped = collect(Tables.rows(roundtripped))
        @test length(roundtripped) == length(signals)
        for (r, s) in zip(roundtripped, signals)
            @test getfield(s, :_row) == NamedTuple(r)
            @test getfield(s, :_row) == getfield(Signal(r), :_row)
        end
    end
end