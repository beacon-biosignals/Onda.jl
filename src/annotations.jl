#####
##### Annotation
#####

# Note that the real field type restrictions here are more lax than the documented
# ones for improved compatibility with data produced by older Onda.jl versions and/or
# non-Julia producers.
"""
    const Annotation = Legolas.@row("onda.annotation@1",
                                    recording::UUID,
                                    id::UUID,
                                    span::TimeSpan)

A type alias for [`Legolas.Row{typeof(Legolas.Schema("onda.annotation@1"))}`](https://beacon-biosignals.github.io/Legolas.jl/stable/#Legolas.@row)
representing an [`onda.annotation` as described by the Onda Format Specification](https://github.com/beacon-biosignals/Onda.jl##ondaannotation1).

This type primarily exists to aid in the validated row construction, and is not intended to be used
as a type constraint in function or struct definitions. Instead, you should generally duck-type any
"annotation-like" arguments/fields so that other generic row types will compose with your code.
"""
const Annotation = @row("onda.annotation@1",
                        recording::Union{UInt128,UUID} = UUID(recording),
                        id::Union{UInt128,UUID} = UUID(id),
                        span::Union{NamedTupleTimeSpan,TimeSpan} = TimeSpan(span))

"""
    write_annotations(io_or_path, table; kwargs...)

Invoke/return `Legolas.write(path_or_io, annotations, Schema("onda.annotation@1"); kwargs...)`.
"""
write_annotations(path_or_io, annotations; kwargs...) = Legolas.write(path_or_io, annotations, Legolas.Schema("onda.annotation@1"); kwargs...)

"""
    validate_annotations(annotations)

Perform both table-level and row-level validation checks on the content of `annotations`,
a presumed `onda.annotation` table. Returns `annotations`.

This function will throw an error in any of the following cases:

- `Legolas.validate(annotations, Legolas.Schema("onda.annotation@1"))` throws an error
- `Annotation(row)` errors for any `row in Tables.rows(annotations)`
- `annotations` contains rows with duplicate `id`s
"""
function validate_annotations(annotations)
    Legolas.validate(annotations, Legolas.Schema("onda.annotation@1"))
    id_counts = Dict{UUID,Int}()
    for (i, row) in enumerate(Tables.rows(annotations))
        local annotation
        try
            annotation = Annotation(row)
        catch err
            log("Encountered invalid row $i of given `onda.annotation` table:")
            rethrow(err)
        end
        id_counts[annotation.id] = get(id_counts, annotation.id, 0) + 1
    end
    filter!(((_, c),) -> c > 1, id_counts)
    if !isempty(id_counts)
        throw(ArgumentError("duplicate `id`s found in given `onda.annotation` table: $id_counts"))
    end
    return annotations
end

#####
##### utilities
#####

"""
    merge_overlapping_annotations(annotations)

Given the `onda.annotation`-compliant table `annotations`, return
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
    for (rid, (locs,)) in Legolas.locations((columns.recording,))
        subset = (recording=view(columns.recording, locs), id=view(columns.id, locs), span=view(columns.span, locs))
        p = sortperm(subset.span; by=TimeSpans.start)
        sorted = Tables.rows((recording=view(subset.recording, p), id=view(subset.id, p), span=view(subset.span, p)))
        init = first(sorted)
        push!(merged, Annotation(recording=rid, id=uuid4(), span=init.span, from=[init.id]))
        for next in Iterators.drop(sorted, 1)
            prev = merged[end]
            if next.recording == prev.recording && TimeSpans.overlaps(next.span, prev.span)
                push!(prev.from, next.id)
                merged[end] = Annotation(Tables.rowmerge(prev; span=TimeSpans.shortest_timespan_containing((prev.span, next.span))))
            else
                push!(merged, Annotation(; recording=next.recording, id=uuid4(), span=next.span, from=[next.id]))
            end
        end
    end
    return merged
end
