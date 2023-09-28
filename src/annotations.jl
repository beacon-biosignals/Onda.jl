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
    @version MergedAnnotationV1 > AnnotationV1 begin
        from::Vector{UUID}
    end

A Legolas-generated record type representing an annotation derived from "merging" one or more existing annotations.

This record type extends `AnnotationV1` with a single additional required field, `from::Vector{UUID}`, whose entries
are the `id`s of the annotation's source annotation(s).

See https://github.com/beacon-biosignals/Legolas.jl for details regarding Legolas record types.
"""
MergedAnnotationV1

"""
    merge_overlapping_annotations([predicate=TimeSpans.overlaps,] annotations)

Given the `onda.annotation@1`-compliant table `annotations`, return a `Vector{MergedAnnotationV1}` where "overlapping"
consecutive entries of `annotations` have been merged using `TimeSpans.shortest_timespan_containing`.

Two consecutive annotations `a` and `b` are determined to be "overlapping" if `a.recording == b.recording && predicate(a.span, b.span)`.
Merged annotations' `span` fields are generated via calling `TimeSpans.shortest_timespan_containing` on the overlapping set of source
annotations.

Note that every annotation in the returned table has a freshly generated `id` field and a non-empty `from` field. An output annotation
whose `from` field only a contains a single element corresponds to an individual non-overlapping annotation in the provided `annotations`.

Note that this function internally works with `Tables.columns(annotations)` rather than `annotations` directly, so it may be slower and/or
require more memory if `!Tables.columnaccess(annotations)`.

See also `TimeSpans.merge_spans` for similar functionality on generic time spans (instead of annotations).
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

@schema "onda.contextless-annotation" ContextlessAnnotation

"""
    @version ContextlessAnnotationV1 begin
        id::UUID
        span::TimeSpan
    end

Represents an event that occurs at some span `span` in a situation in which the broader context of the recording
and what the `span` is relative to is not available.

This can be useful when annotations are being generated from [`Samples`](@ref) objects, without the context of the [`SignalV2`](@ref)
that these samples came from.

These can be upgraded to full `AnnotationV1`'s via [`add_context`](@ref).
"""
ContextlessAnnotationV1

@version ContextlessAnnotationV1 begin
    id::UUID
    span::TimeSpan
end

"""
    add_context(contextless; recording, start) -> AnnotationV1

Given a contextless annotation (see also [`ContextlessAnnotationV1`](@ref)), adds the context of the `recording`
associated to this annotation, and the `start` time relative to the recording.

For example, if you load a signal `signal` (and hence know the recording and start of the signal relative to the recording),
to obtain a `Samples` object, and then generate contextless annotations from that samples object alone (e.g. via another library),
you can "upgrade" these to full annotations by `add_context(contextless; signal.recording, start=start(signal.span))`.

This function simply translates the `span` field of `contextless` by `start` and adds the recording field.
"""
add_context(contextless; recording, start) = AnnotationV1(; contextless.id, recording, span=translate(contextless.span, start))
