#####
##### Annotation
#####

"""
TODO
"""
const Annotation = @row("onda.annotation@1",
                        recording::UUID = UUID(recording),
                        id::UUID = UUID(id),
                        span::TimeSpan = TimeSpan(span))

#####
##### utilities
#####

"""
    merge_overlapping_annotations(annotations)

Given the `*.onda.annotations.arrow`-compliant table `annotations`, return
a table corresponding to `annotations` except that overlapping entries have
been merged.

Specifically, two annotations `a` and `b` are determined to be "overlapping"
if `a.recording == b.recording && TimeSpans.overlaps(a.span, b.span)`. Merged
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
"""
function merge_overlapping_annotations(annotations)
    columns = Tables.columns(annotations)
    merged = Annotation[]
    for (rid, (locs,)) in locations((columns.recording,))
        subset = (recording=view(columns.recording, locs), id=view(columns.id, locs), span=view(columns.span, locs))
        p = sortperm(subset.span; by=TimeSpans.start)
        sorted = Tables.rows((recording=view(subset.recording, p), id=view(subset.id, p), span=view(subset.span, p)))
        init = first(sorted)
        push!(merged, Annotation(rid, uuid4(), init.span; from=[init.id]))
        for next in Iterators.drop(sorted, 1)
            prev = merged[end]
            if next.recording == prev.recording && TimeSpans.overlaps(next.span, prev.span)
                push!(prev.from, next.id)
                merged[end] = setproperties(prev; span=TimeSpans.shortest_timespan_containing((prev.span, next.span)))
            else
                push!(merged, Annotation(next.recording, uuid4(), next.span; from=[next.id]))
            end
        end
    end
    return merged
end
