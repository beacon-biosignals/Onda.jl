@testset "`onda.annotation` Legolas configuration" begin
    @test Legolas.declared(AnnotationV1SchemaVersion())
    @test Legolas.required_fields(AnnotationV1SchemaVersion()) == (recording=UUID, id=UUID, span=TimeSpan)
    @test Legolas.accepted_field_type(AnnotationV1SchemaVersion(), TimeSpan) == Union{Onda.NamedTupleTimeSpan,TimeSpan}

    @test Legolas.declared(MergedAnnotationV1SchemaVersion())
    @test Legolas.required_fields(MergedAnnotationV1SchemaVersion()) == (recording=UUID, id=UUID, span=TimeSpan, from=Vector{UUID})
end

@testset "`validate_annotations`" begin
    template = (recording=uuid4(), id=uuid4(), span=TimeSpan(0, 1), custom=1234)
    @test AnnotationV1(template) isa AnnotationV1
    good = [template, rowmerge(template; id=uuid4()), rowmerge(template; id=uuid4())]
    @test validate_annotations(good) === good
    @test_throws ArgumentError validate_annotations(vcat(good, template))
    @test_throws ArgumentError validate_annotations([template, template, template])
    @test_throws ArgumentError validate_annotations((x=[1, 2, 3], y=["lol", "bad", "table"]))
end

@testset "`merge_overlapping_annotations`" begin
    recs = (uuid4(), uuid4(), uuid4())
    sources = [AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(0, 100)), #= 1 =#
        AnnotationV1(recording=recs[2], id=uuid4(), span=TimeSpan(55, 100)),               #= 2 =#
        AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(34, 76)),               #= 3 =#
        AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(120, 176)),               #= 4 =#
        AnnotationV1(recording=recs[2], id=uuid4(), span=TimeSpan(67, 95)),               #= 5 =#
        AnnotationV1(recording=recs[2], id=uuid4(), span=TimeSpan(15, 170)),               #= 6 =#
        AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(43, 89)),               #= 7 =#
        AnnotationV1(recording=recs[3], id=uuid4(), span=TimeSpan(0, 50)),               #= 8 =#
        AnnotationV1(recording=recs[2], id=uuid4(), span=TimeSpan(2, 10)),               #= 9 =#
        AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(111, 140)),               #= 10 =#
        AnnotationV1(recording=recs[3], id=uuid4(), span=TimeSpan(60, 100)),               #= 11 =#
        AnnotationV1(recording=recs[3], id=uuid4(), span=TimeSpan(23, 80)),               #= 12 =#
        AnnotationV1(recording=recs[3], id=uuid4(), span=TimeSpan(100, 110)),               #= 13 =#
        AnnotationV1(recording=recs[1], id=uuid4(), span=TimeSpan(200, 300))]               #= 14 =#
    merged = merge_overlapping_annotations(sources)
    @test merged isa Vector{MergedAnnotationV1}
    merged = Tables.columns(merged)
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
    merged = @compat Set(Tables.rowtable((; merged.recording, merged.span, merged.from)))
    expected = Set([(recording=recs[1], span=TimeSpan(0, 176), from=[sources[1].id, sources[3].id, sources[7].id, sources[10].id, sources[4].id]),
        (recording=recs[1], span=TimeSpan(200, 300), from=[sources[14].id]),
        (recording=recs[2], span=TimeSpan(2, 170), from=[sources[9].id, sources[6].id, sources[2].id, sources[5].id]),
        (recording=recs[3], span=TimeSpan(0, 110), from=[sources[8].id, sources[12].id, sources[11].id, sources[13].id])])
    @test expected == merged
end

@testset "contextless-annotation" begin
    c = ContextlessAnnotationV1(; id=uuid4(), span=TimeSpan(2, 3))

    recording = uuid4()
    ann = add_context(c; recording, start=Nanosecond(5))
    @test ann isa AnnotationV1
    @test ann.id == c.id
    @test ann.recording == recording

    # What is the right answer? Let us draw a diagram
    # (---------------recording----------------------------------------)
    #         (--------signal---------------------------)
    #                (----contextless.span-----)
    # -------> start(signal.span)
    #         ------> start(contextless.span)
    # --------------> start(translate(contextless.span, start(signal.span)))

    @test ann.span == TimeSpan(7, 8)

    # Can use other types. Extra columns are ignored.
    ann2 = add_context(Tables.rowmerge(c; garbo="hi"); recording, start=Nanosecond(5))
    @test ann2 == ann
end
