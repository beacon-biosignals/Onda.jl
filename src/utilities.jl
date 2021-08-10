log(message) = @info "$(now()) | $message"

const ALPHANUMERIC_SNAKE_CASE_CHARACTERS = Char['_',
                                                '0':'9'...,
                                                'a':'z'...]

function is_lower_snake_case_alphanumeric(x::AbstractString, also_allow=())
    return !startswith(x, '_') && !endswith(x, '_') &&
           all(i -> i in ALPHANUMERIC_SNAKE_CASE_CHARACTERS || i in also_allow, x)
end

# TODO port a generic version of this + notion of primary key to Legolas.jl
function _fully_validate_legolas_table(table, schema::Legolas.Schema, primary_key)
    Legolas.validate(table, schema)
    primary_counts = Dict{Any,Int}()
    for (i, row) in enumerate(Tables.rows(table))
        local validated_row
        try
            validated_row = Legolas.Row(schema, row)
        catch err
            log("Encountered invalid row $i when validating table's compliance with $schema:")
            rethrow(err)
        end
        primary = Tables.getcolumn(validated_row, primary_key)
        primary_counts[primary] = get(primary_counts, primary, 0) + 1
    end
    filter!(>(1) ∘ last, primary_counts)
    if !isempty(primary_counts)
        throw(ArgumentError("duplicate $primary_key values found in given $schema table: $primary_counts"))
    end
    return table
end

#####
##### arrrrr i'm a pirate
#####
# The Onda Format defines `span` elements to correspond to the Arrow-equivalent of `(start=Nanosecond(...), stop=Nanosecond(...))`.
# Here we define the generic `TimeSpans` interface on this type in order to ensure that this structure can be treated like a
# `TimeSpan` anywhere. This way, callers don't need to do any fiddling if e.g. they're working with an Onda file written from
# a source that wasn't using `TimeSpans` (e.g. if it was written out by a non-Julia process).

const NamedTupleTimeSpan = NamedTuple{(:start, :stop),Tuple{Nanosecond,Nanosecond}}

TimeSpans.istimespan(::NamedTupleTimeSpan) = true
TimeSpans.start(x::NamedTupleTimeSpan) = x.start
TimeSpans.stop(x::NamedTupleTimeSpan) = x.stop

const TIME_SPAN_ARROW_NAME = Symbol("JuliaLang.TimeSpan")

Arrow.ArrowTypes.arrowname(::Type{TimeSpan}) = TIME_SPAN_ARROW_NAME
ArrowTypes.JuliaType(::Val{TIME_SPAN_ARROW_NAME}) = TimeSpan

#####
##### zstd_compress/zstd_decompress
#####

function zstd_compress(bytes::Vector{UInt8}, level=3)
    compressor = ZstdCompressor(; level=level)
    TranscodingStreams.initialize(compressor)
    compressed_bytes = transcode(compressor, bytes)
    TranscodingStreams.finalize(compressor)
    return compressed_bytes
end

zstd_decompress(bytes::Vector{UInt8}) = transcode(ZstdDecompressor, bytes)

#####
##### read/write/bytes/streams
#####

jump(io::IO, n) = (read(io, n); nothing)
jump(io::IOStream, n) = (skip(io, n); nothing)
jump(io::IOBuffer, n) = ((io.seekable ? skip(io, n) : read(io, n)); nothing)

unsafe_vec_uint8(x::AbstractVector{UInt8}) = convert(Vector{UInt8}, x)
unsafe_vec_uint8(x::Base.ReinterpretArray{UInt8,1}) = unsafe_wrap(Vector{UInt8}, pointer(x), length(x))

"""
    read_byte_range(path, byte_offset, byte_count)

Return the equivalent `read(path)[(byte_offset + 1):(byte_offset + byte_count)]`,
but try to avoid reading unreturned intermediate bytes. Note that the
effectiveness of this method depends on the type of `path`.
"""
function read_byte_range(path, byte_offset, byte_count)
    return open(path, "r") do io
        jump(io, byte_offset)
        return read(io, byte_count)
    end
end

read_byte_range(path, ::Missing, ::Missing) = read(path)

write_full_path(path::AbstractString, bytes) = (mkpath(dirname(path)); write(path, bytes))
write_full_path(path, bytes) = write(path, bytes)
