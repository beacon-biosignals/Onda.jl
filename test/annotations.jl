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
    @test has_rows(Annotation(Annotation(row)), norm_row)
    @test has_rows(Annotation(Annotation(row_with_custom)), norm_row_with_custom)
    @test has_rows(Annotation(Tables.Row(row)), norm_row)
    @test has_rows(Annotation(Tables.Row(row_with_custom)), norm_row_with_custom)
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
    io = IOBuffer()
    write_annotations(annotations_file_path, annotations)
    write_annotations(io, annotations)
    seekstart(io)
    for roundtripped in (read_annotations(annotations_file_path; materialize=false, validate_schema=false),
                         read_annotations(annotations_file_path; materialize=true, validate_schema=true),
                         read_annotations(io; validate_schema=true))
        roundtripped = collect(Tables.rows(roundtripped))
        @test length(roundtripped) == length(annotations)
        for (r, a) in zip(roundtripped, annotations)
            @test getfield(a, :_row) == NamedTuple(r)
            @test getfield(a, :_row) == getfield(Annotation(r), :_row)
        end
    end
end

@testset "`merge_overlapping_annotations`" begin
    recs = (uuid4(), uuid4(), uuid4())
    sources = [#= 1 =#  Annotation(recs[1], uuid4(), TimeSpan(0, 100)),
               #= 2 =#  Annotation(recs[2], uuid4(), TimeSpan(55, 100)),
               #= 3 =#  Annotation(recs[1], uuid4(), TimeSpan(34, 76)),
               #= 4 =#  Annotation(recs[1], uuid4(), TimeSpan(120, 176)),
               #= 5 =#  Annotation(recs[2], uuid4(), TimeSpan(67, 95)),
               #= 6 =#  Annotation(recs[2], uuid4(), TimeSpan(15, 170)),
               #= 7 =#  Annotation(recs[1], uuid4(), TimeSpan(43, 89)),
               #= 8 =#  Annotation(recs[3], uuid4(), TimeSpan(0, 50)),
               #= 9 =#  Annotation(recs[2], uuid4(), TimeSpan(2, 10)),
               #= 10 =# Annotation(recs[1], uuid4(), TimeSpan(111, 140)),
               #= 11 =# Annotation(recs[3], uuid4(), TimeSpan(60, 100)),
               #= 12 =# Annotation(recs[3], uuid4(), TimeSpan(23, 80)),
               #= 13 =# Annotation(recs[3], uuid4(), TimeSpan(100, 110)),
               #= 14 =# Annotation(recs[1], uuid4(), TimeSpan(200, 300))]
    merged = Tables.columns(merge_overlapping_annotations(sources))
    @test Tables.columnnames(merged) == (:recording, :id, :span, :from)
    sources_id = [row.id for row in sources]
    @test !any(in(id, sources_id) for id in merged.id)
    merged = Set(Tables.rowtable((; merged.recording, merged.span, merged.from)))
    expected = Set([(recording=recs[1], span=TimeSpan(0, 100), from=[sources[1].id, sources[3].id, sources[7].id]),
                    (recording=recs[1], span=TimeSpan(111, 176), from=[sources[10].id, sources[4].id]),
                    (recording=recs[1], span=TimeSpan(200, 300), from=[sources[14].id]),
                    (recording=recs[2], span=TimeSpan(15, 170), from=[sources[6].id, sources[2].id, sources[5].id]),
                    (recording=recs[2], span=TimeSpan(2, 10), from=[sources[9].id]),
                    (recording=recs[3], span=TimeSpan(100, 110), from=[sources[13].id]),
                    (recording=recs[3], span=TimeSpan(0, 100), from=[sources[8].id, sources[12].id, sources[11].id])])
    @test expected == merged
end