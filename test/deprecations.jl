@testset "upgrade_onda_dataset_to_v0_5!/downgrade_onda_dataset_to_v0_4!" begin
    new_path = mktempdir()
    old_path = joinpath(@__DIR__, "old_test_v0_3.onda")
    cp(old_path, new_path; force=true)
    Onda.upgrade_onda_dataset_to_v0_5!(new_path)
    signals = DataFrame(read_signals(joinpath(new_path, "upgraded.onda.signals.arrow")))
    annotations = DataFrame(read_annotations(joinpath(new_path, "upgraded.onda.annotations.arrow")))

    downgraded_path = mktempdir()
    Onda.downgrade_onda_dataset_to_v0_4!(downgraded_path, signals, annotations)
    downgraded_header, downgraded_recordings = MsgPack.unpack(Onda.zstd_decompress(read(joinpath(downgraded_path, "recordings.msgpack.zst"))))
    @test downgraded_header == Dict("onda_format_version" => "v0.4.0", "ordered_keys" => false)

    _, old_recordings = MsgPack.unpack(Onda.zstd_decompress(read(joinpath(new_path, "recordings.msgpack.zst"))))
    new_recordings = Onda.gather(:recording, signals, annotations)
    for (uuid, old_recording) in old_recordings
        new_signals, new_annotations = new_recordings[UUID(uuid)]
        downgraded_recording = downgraded_recordings[uuid]
        @test length(old_recording["signals"]) == nrow(new_signals)
        @test length(old_recording["annotations"]) == nrow(new_annotations)
        for (old_kind, old_signal) in old_recording["signals"]
            new_signal = view(new_signals, findall(==(old_kind), new_signals.kind), :)
            @test old_signal == downgraded_recording["signals"][old_kind]
            @test nrow(new_signal) == 1
            @test new_signal.file_path[] == joinpath("samples", uuid, old_kind * "." * old_signal["file_extension"])
            @test new_signal.file_format[] == old_signal["file_extension"]
            @test new_signal.span[] == TimeSpan(old_signal["start_nanosecond"], old_signal["stop_nanosecond"])
            @test new_signal.channels[] == old_signal["channel_names"]
            @test new_signal.sample_unit[] == old_signal["sample_unit"]
            @test new_signal.sample_resolution_in_unit[] == old_signal["sample_resolution_in_unit"]
            @test new_signal.sample_offset_in_unit[] == old_signal["sample_offset_in_unit"]
            @test new_signal.sample_type[] == old_signal["sample_type"]
            @test new_signal.sample_rate[] == old_signal["sample_rate"]
        end
        for old_annotation in old_recording["annotations"]
            old_span = TimeSpan(old_annotation["start_nanosecond"], old_annotation["stop_nanosecond"])
            new_annotation = filter(a -> a.value == old_annotation["value"] && a.span == old_span, new_annotations)
            @test nrow(new_annotation) == 1
            @test new_annotation.recording[] == UUID(uuid)
        end
        for downgraded_annotation in downgraded_recording["annotations"]
            downgraded_span = TimeSpan(downgraded_annotation["start_nanosecond"], downgraded_annotation["stop_nanosecond"])
            downgraded_value = Onda.JSON3.read(downgraded_annotation["value"])
            new_annotation = filter(a -> a.id == UUID(downgraded_value.id) && a.span == downgraded_span && a.value == downgraded_value.value,
                                    new_annotations)
            @test nrow(new_annotation) == 1
            @test new_annotation.recording[] == UUID(uuid)
        end
    end
end



# @testset "`read_annotations`/`write_annotations`" begin
#     root = mktempdir()
#     possible_recordings = (uuid4(), uuid4(), uuid4())
#     annotations = Annotation[Annotation(recording=rand(possible_recordings),
#                                         id=uuid4(),
#                                         span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
#                                         a=join(rand('a':'z', 10)),
#                                         b=rand(Int, 1),
#                                         c=rand(3)) for i in 1:50]
#     annotations_file_path = joinpath(root, "test.onda.annotations.arrow")
#     cols = Tables.columns(annotations)
#     Onda.assign_to_table_metadata!(cols, ("a" => "b", "x" => "y"))
#     io = IOBuffer()
#     write_annotations(annotations_file_path, cols)
#     write_annotations(io, cols)
#     seekstart(io)
#     for roundtripped in (read_annotations(annotations_file_path; materialize=false, validate_schema=false),
#                          read_annotations(annotations_file_path; materialize=true, validate_schema=true),
#                          Onda.materialize(read_annotations(io)),
#                          read_annotations(seekstart(io); validate_schema=true))
#         if roundtripped isa Onda.Arrow.Table
#             @test Onda.table_has_metadata(m -> m["onda_format_version"] == "v$(Onda.MAXIMUM_ONDA_FORMAT_VERSION)" &&
#                                                m["a"] == "b" && m["x"] == "y", roundtripped)
#         end
#         roundtripped = collect(Tables.rows(roundtripped))
#         @test length(roundtripped) == length(annotations)
#         for (r, a) in zip(roundtripped, annotations)
#             @test getfield(a, :_row) == NamedTuple(r)
#             @test getfield(a, :_row) == getfield(Annotation(r), :_row)
#         end
#     end
# end

# @testset "`read_signals`/`write_signals`" begin
#     root = mktempdir()
#     possible_recordings = (uuid4(), uuid4(), uuid4())
#     possible_sample_types = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64)
#     signals = Signal[Signal(recording=rand(possible_recordings),
#                             file_path=joinpath(root, "x_$(i)_file"),
#                             file_format=rand(("lpcm", "lpcm.zst")),
#                             span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
#                             kind="x_$i",
#                             channels=["a_$i", "b_$i", "c_$i"],
#                             sample_unit="unit_$i",
#                             sample_resolution_in_unit=rand((0.25, 1)),
#                             sample_offset_in_unit=rand((-0.25, 0.25)),
#                             sample_type=rand(possible_sample_types),
#                             sample_rate=rand((128, 50.5)),
#                             a=join(rand('a':'z', 10)),
#                             b=rand(Int, 1),
#                             c=rand(3)) for i in 1:50]
#     signals_file_path = joinpath(root, "test.onda.signals.arrow")
#     io = IOBuffer()
#     write_signals(signals_file_path, signals)
#     write_signals(io, signals)
#     seekstart(io)
#     io2 = IOBuffer()
#     write_signals(io2, signals; file=false)
#     seekstart(io2)
#     for roundtripped in (read_signals(signals_file_path; materialize=false, validate_schema=false),
#                          read_signals(signals_file_path; materialize=true, validate_schema=true),
#                          Onda.materialize(read_signals(io)),
#                          Onda.materialize(read_signals(io2)),
#                          read_signals(seekstart(io); validate_schema=true))
#         roundtripped = collect(Tables.rows(roundtripped))
#         @test length(roundtripped) == length(signals)
#         for (r, s) in zip(roundtripped, signals)
#             @test getfield(s, :_row) == NamedTuple(r)
#             @test getfield(s, :_row) == getfield(Signal(r), :_row)
#         end
#     end
# end