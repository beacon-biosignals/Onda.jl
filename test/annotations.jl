function test_annotation_row(recording, id, span; custom...)
    row = @compat (; recording, id, span)
    row_with_custom = (; row..., custom...)

    @test Arrow.Table(Legolas.tobuffer([row], Legolas.Schema("onda.annotation@1"); validate=true)) isa Arrow.Table
    @test Arrow.Table(Legolas.tobuffer([row_with_custom], Legolas.Schema("onda.annotation@1"); validate=true)) isa Arrow.Table

    # intended normalization of input fields for constructor
    recording::UUID = recording isa UUID ? recording : UUID(recording)
    id::UUID = id isa UUID ? id : UUID(id)
    span::TimeSpan = TimeSpan(span)
    norm_row = @compat (; recording, id, span)
    norm_row_with_custom = (; norm_row..., custom...)

    @test has_rows(Annotation(row), norm_row)
    @test has_rows(Annotation(row_with_custom), norm_row_with_custom)
    @test has_rows(Annotation(Annotation(row)), norm_row)
    @test has_rows(Annotation(Annotation(row_with_custom)), norm_row_with_custom)
    @test has_rows(Annotation(Tables.Row(row)), norm_row)
    @test has_rows(Annotation(Tables.Row(row_with_custom)), norm_row_with_custom)
    @test has_rows(Annotation(; row...), norm_row)
    @test has_rows(Annotation(; row..., custom...), norm_row_with_custom)
end

@testset "`Annotation` construction/access" begin
    custom = (a="test", b=1, c=[2.0, 3.0])
    test_annotation_row(UInt128(uuid4()), UInt128(uuid4()), (start=Nanosecond(1), stop=Nanosecond(100)); custom...)
    test_annotation_row(uuid4(), uuid4(), TimeSpan(Nanosecond(1), Nanosecond(100)); custom...)
end

@testset "`onda.annotation` validation" begin
    template = (recording=uuid4(), id=uuid4(), span=TimeSpan(0, 1), custom=1234)
    @test Annotation(template) isa Annotation
    good = [template, Tables.rowmerge(template; id=uuid4()), Tables.rowmerge(template; id=uuid4())]
    @test validate_annotations(good) === good
    @test_throws ArgumentError validate_annotations(vcat(good, template))
    @test_throws ArgumentError validate_annotations([template, template, template])
    @test_throws ArgumentError validate_annotations((x=[1, 2, 3], y=["lol", "bad", "table"]))
end

@testset "`merge_overlapping_annotations`" begin
    recs = (uuid4(), uuid4(), uuid4())
    sources = [#= 1 =#  Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(0, 100)),
               #= 2 =#  Annotation(recording=recs[2], id=uuid4(), span=TimeSpan(55, 100)),
               #= 3 =#  Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(34, 76)),
               #= 4 =#  Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(120, 176)),
               #= 5 =#  Annotation(recording=recs[2], id=uuid4(), span=TimeSpan(67, 95)),
               #= 6 =#  Annotation(recording=recs[2], id=uuid4(), span=TimeSpan(15, 170)),
               #= 7 =#  Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(43, 89)),
               #= 8 =#  Annotation(recording=recs[3], id=uuid4(), span=TimeSpan(0, 50)),
               #= 9 =#  Annotation(recording=recs[2], id=uuid4(), span=TimeSpan(2, 10)),
               #= 10 =# Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(111, 140)),
               #= 11 =# Annotation(recording=recs[3], id=uuid4(), span=TimeSpan(60, 100)),
               #= 12 =# Annotation(recording=recs[3], id=uuid4(), span=TimeSpan(23, 80)),
               #= 13 =# Annotation(recording=recs[3], id=uuid4(), span=TimeSpan(100, 110)),
               #= 14 =# Annotation(recording=recs[1], id=uuid4(), span=TimeSpan(200, 300))]
    merged = Tables.columns(merge_overlapping_annotations(sources))
    @test Tables.columnnames(merged) == (:recording, :id, :span, :from)
    sources_id = [row.id for row in sources]
    @test !any(in(id, sources_id) for id in merged.id)
    merged = @compat Set(Tables.rowtable((; merged.recording, merged.span, merged.from)))
    expected = Set([(recording=recs[1], span=TimeSpan(0, 100), from=[sources[1].id, sources[3].id, sources[7].id]),
                    (recording=recs[1], span=TimeSpan(111, 176), from=[sources[10].id, sources[4].id]),
                    (recording=recs[1], span=TimeSpan(200, 300), from=[sources[14].id]),
                    (recording=recs[2], span=TimeSpan(15, 170), from=[sources[6].id, sources[2].id, sources[5].id]),
                    (recording=recs[2], span=TimeSpan(2, 10), from=[sources[9].id]),
                    (recording=recs[3], span=TimeSpan(100, 110), from=[sources[13].id]),
                    (recording=recs[3], span=TimeSpan(0, 100), from=[sources[8].id, sources[12].id, sources[11].id])])
    @test expected == merged

    # now let's try where we merge consecutive spans even if there's a gap, if it's less than 15 ns
    predicate(next, prev) = start(next) - stop(prev) < Nanosecond(15)
    
    merged = Tables.columns(merge_overlapping_annotations(predicate, sources))
    @test Tables.columnnames(merged) == (:recording, :id, :span, :from)
    sources_id = [row.id for row in sources]
    @test !any(in(id, sources_id) for id in merged.id)
    global merged, expected, sources
    merged = @compat Set(Tables.rowtable((; merged.recording, merged.span, merged.from)))
    expected = Set([(recording=recs[1], span=TimeSpan(0, 176), from=[sources[1].id, sources[3].id, sources[7].id, sources[10].id, sources[4].id]),
                    (recording=recs[1], span=TimeSpan(200, 300), from=[sources[14].id]),
                    (recording=recs[2], span=TimeSpan(2, 170), from=[sources[9].id, sources[6].id, sources[2].id, sources[5].id]),
                    (recording=recs[3], span=TimeSpan(0, 110), from=[sources[8].id, sources[12].id, sources[11].id, sources[13].id])])
    @test expected == merged
end
