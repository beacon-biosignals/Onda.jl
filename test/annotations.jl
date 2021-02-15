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