function test_annotation_row(recording, id, span; custom...)
    row = (; recording, id, span)
    row_with_custom = (; row..., custom...)

    # intended normalization of input fields for constructor
    recording::UUID = recording isa UUID ? recording : UUID(recording)
    id::UUID = id isa UUID ? id : UUID(id)
    span::TimeSpan = TimeSpan(span)
    norm_row = (; recording, id, span)
    norm_row_with_custom = (; norm_row..., custom...)

    @test has_rows(Annotation(row), norm_row)
    @test has_rows(Annotation(row_with_custom), norm_row_with_custom)
    @test has_rows(Annotation(row...), norm_row)
    @test has_rows(Annotation(; row...), norm_row)
    @test has_rows(Annotation(row...; custom...), norm_row_with_custom)
    @test has_rows(Annotation(; row..., custom...), norm_row_with_custom)
end

@testset "`Annotation` construction/access" begin
    custom = (a="test", b=1, c=[2.0, 3.0])
    test_annotation_row(UInt128(uuid4()), UInt128(uuid4()), (start=Nanosecond(1), stop=Nanosecond(100)); custom...)
    test_annotation_row(uuid4(), uuid4(), TimeSpan(Nanosecond(1), Nanosecond(100)); custom...)
end

@testset "`read_annotations`/`write_annotations`" begin
    root = mktempdir()
    possible_recordings = (uuid4(), uuid4(), uuid4())
    annotations = Annotation[Annotation(recording=rand(possible_recordings),
                                        id=uuid4(),
                                        span=TimeSpan(Second(rand(0:30)), Second(rand(31:60))),
                                        a=join(rand('a':'z', 10)),
                                        b=rand(Int, 1),
                                        c=rand(3)) for i in 1:50]
    annotations_file_path = joinpath(root, "test.onda.annotations.arrow")
    write_annotations(annotations_file_path, annotations)
    for roundtripped in (read_annotations(annotations_file_path; materialize=false, validate_schema=false),
                         read_annotations(annotations_file_path; materialize=true, validate_schema=true))
        roundtripped = collect(Tables.rowtable(roundtripped))
        @test length(roundtripped) == length(annotations)
        for (r, s) in zip(roundtripped, annotations)
            @test r == getfield(s, :_row)
        end
    end
end

# @testset "`merge_overlapping_annotations`" begin

# end