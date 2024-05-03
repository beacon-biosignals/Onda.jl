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

@testset "`onda.samples-info` Legolas configuration" begin
    @test Legolas.declared(SamplesInfoV2SchemaVersion())
    @test Legolas.required_fields(SamplesInfoV2SchemaVersion()) == (sensor_type=String,
                                                                    channels=Vector{String},
                                                                    sample_unit=String,
                                                                    sample_resolution_in_unit=Float64,
                                                                    sample_offset_in_unit=Float64,
                                                                    sample_type=String,
                                                                    sample_rate=Float64)
    template = (; sensor_type="x", channels=["a"], sample_unit="unit", sample_resolution_in_unit=1, sample_offset_in_unit=0, sample_rate=128)
    for st in ("int8", "int16", "int32", "int64", "uint8", "uint16", "uint32", "uint64", "float32", "float64")
        @test SamplesInfoV2(rowmerge(template; sample_type=st)).sample_type == st
    end
    @test_throws ArgumentError SamplesInfoV2(rowmerge(template; sample_type="no"))
    @test_throws ArgumentError SamplesInfoV2(rowmerge(template; sample_type="Int8"))
    @test_throws ArgumentError SamplesInfoV2(rowmerge(template; sample_type="int24"))
    @test_throws ArgumentError SamplesInfoV2(rowmerge(template; sample_type="float16"))
    @test_throws ArgumentError SamplesInfoV2(rowmerge(template; sample_type=" int8"))
end

@testset "`onda.signal` Legolas configuration" begin
    @test Legolas.declared(SignalV2SchemaVersion())
    @test Legolas.parent(SignalV2SchemaVersion()) == SamplesInfoV2SchemaVersion()
    @test Legolas.required_fields(SignalV2SchemaVersion()) == (sensor_type=String,
                                                               channels=Vector{String},
                                                               sample_unit=String,
                                                               sample_resolution_in_unit=Float64,
                                                               sample_offset_in_unit=Float64,
                                                               sample_type=String,
                                                               sample_rate=Float64,
                                                               recording=UUID,
                                                               file_path=Any,
                                                               file_format=String,
                                                               span=TimeSpan,
                                                               sensor_label=String)
    @test Legolas.accepted_field_type(SignalV2SchemaVersion(), TimeSpan) == Union{Onda.NamedTupleTimeSpan,TimeSpan}
end

@testset "`validate_signals`" begin
    template = (recording=uuid4(), file_path="/file/path", file_format="lpcm", span=TimeSpan(0, 1),
                sensor_type="y", sensor_label="x", channels=["a", "b", "c"],
                sample_unit="microvolt", sample_rate=256.0, sample_resolution_in_unit=0.4,
                sample_offset_in_unit=0.4, sample_type="uint8")
    @test SignalV2(template) isa SignalV2
    bad_rows = typeof(template)[rowmerge(template; channels = ["a", "b", "c", "a"]),
                                rowmerge(template; channels = ["a", "B", "c"]),
                                rowmerge(template; channels = ["a", "   ", "c"]),
                                rowmerge(template; sample_type = "not a valid sample type"),
                                rowmerge(template; sample_type = "Tuple"),
                                rowmerge(template; sensor_type = "NO"),
                                rowmerge(template; sensor_type = "   "),
                                rowmerge(template; sensor_label = ""),
                                rowmerge(template; sample_unit = ""),
                                rowmerge(template; sample_unit = "  hA HA")]
    for bad_row in bad_rows
        @test_throws ArgumentError SignalV2(bad_row)
    end
    good = typeof(template)[template, rowmerge(template; file_path="/a/b"), rowmerge(template; file_path="/c/d")]
    @test validate_signals(good) === good
    @test_throws ArgumentError validate_signals(bad_rows)
    @test_throws ArgumentError validate_signals(vcat(good, bad_rows[1]))
    @test_throws ArgumentError validate_signals([template, template, template])
    @test_throws ArgumentError validate_signals((x=[1, 2, 3], y=["lol", "bad", "table"]))
end

@testset "channel name validation" begin
    valid_channels = ["a", "b", "a_b", "a-b", "a-b.c", "a+b", "a-(b+c)/2", "(a+b)/2"]
    for c in valid_channels
        @test Onda._validate_signal_channel(c) == c
    end

    invalid_channels = ["AAA", "AbC", "a*b", "a&b", "a^c", "a-(b+c/2", ")"]
    for c in invalid_channels
        @test_throws ArgumentError Onda._validate_signal_channel(c) == c
    end
end
