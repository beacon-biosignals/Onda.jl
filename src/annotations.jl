#####
##### `onda.annotation`
#####

@schema "onda.annotation" Annotation

@version AnnotationV1 begin
    recording::UUID = UUID(recording)
    id::UUID = UUID(id)
    span::TimeSpan = TimeSpan(span)
end

Legolas.accepted_field_type(::AnnotationV1SchemaVersion, ::Type{TimeSpan}) = Union{NamedTupleTimeSpan,TimeSpan}

"""
    @version AnnotationV1 begin
        recording::UUID
        id::UUID
        span::TimeSpan
    end

A Legolas-generated record type representing an [`onda.annotation` as described by the Onda Format Specification](https://github.com/beacon-biosignals/Onda.jl##ondaannotation1).

See https://github.com/beacon-biosignals/Legolas.jl for details regarding Legolas record types.
"""
AnnotationV1

"""
    validate_annotations(annotations)

Perform both table-level and row-level validation checks on the content of `annotations`,
a presumed `onda.annotation` table. Returns `annotations`.

This function will throw an error in any of the following cases:

- `Legolas.validate(Tables.schema(annotations), AnnotationV1SchemaVersion())` throws an error
- `AnnotationV1(r)` errors for any `r` in `Tables.rows(annotations)`
- `annotations` contains rows with duplicate `id`s
"""
validate_annotations(annotations) = _fully_validate_legolas_table(:validate_annotations, annotations, AnnotationV1, AnnotationV1SchemaVersion(), :id)

#####
##### `merge_overlapping_annotations`
#####

@schema "onda.merged-annotation" MergedAnnotation

@version MergedAnnotationV1 > AnnotationV1 begin
    from::Vector{UUID}
end

"""
    merge_overlapping_annotations([predicate=TimeSpans.overlaps,] annotations)

Given the `onda.annotation`-compliant table `annotations`, return
a table corresponding to `annotations` except that consecutive entries satisfying `predicate`
have been merged using `TimeSpans.shortest_timespan_containing`. The predicate
must be of the form `prediate(next_span::TimeSpan, prev_span::TimeSpan)::Bool`
returning whether or not to merge the annotations corresponding to
`next_span` and `prev_span`, where `next_span` is the next span in the same recording as `prev_span`.

Specifically, two annotations `a` and `b` are determined to be "overlapping"
if `a.recording == b.recording && predicate(a.span, b.span)`, where the default
value of `predicate` is `TimeSpans.overlaps`. Merged
annotations' `span` fields are generated via calling `TimeSpans.shortest_timespan_containing`
on the overlapping set of source annotations.

The returned annotations table only has a single custom column named `from`
whose entries are `Vector{UUID}`s populated with the `id`s of the generated
annotations' source(s). Note that every annotation in the returned table
has a freshly generated `id` field and a non-empty `from` field, even if
the `from` only has a single element (i.e. corresponds to a single
non-overlapping annotation).

Note that this function internally works with `Tables.columns(annotations)`
rather than `annotations` directly, so it may be slower and/or require more
memory if `!Tables.columnaccess(annotations)`.

See also `TimeSpans.merge_spans` for similar functionality on timespans (instead of annotations).
"""
function merge_overlapping_annotations(predicate, annotations)
    columns = Tables.columns(annotations)
    merged = MergedAnnotationV1[]
    for (rid, (locs,)) in Legolas.locations((columns.recording,))
        subset = (recording=view(columns.recording, locs), id=view(columns.id, locs), span=view(columns.span, locs))
        p = sortperm(subset.span; by=TimeSpans.start)
        sorted = Tables.rows((recording=view(subset.recording, p), id=view(subset.id, p), span=view(subset.span, p)))
        init = first(sorted)
        push!(merged, MergedAnnotationV1(; recording=rid, id=uuid4(), span=init.span, from=[init.id]))
        for next in Iterators.drop(sorted, 1)
            prev = merged[end]
            if next.recording == prev.recording && predicate(next.span, prev.span)
                push!(prev.from, next.id)
                merged[end] = MergedAnnotationV1(rowmerge(prev; span=TimeSpans.shortest_timespan_containing((prev.span, next.span))))
            else
                push!(merged, MergedAnnotationV1(; recording=next.recording, id=uuid4(), span=next.span, from=[next.id]))
            end
        end
    end
    return merged
end

merge_overlapping_annotations(annotations) = merge_overlapping_annotations(overlaps, annotations)
