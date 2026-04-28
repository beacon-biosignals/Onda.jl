#####
##### Compare encoded sizes for hypnogram-style sample data across formats.
#####
##### Run from the OndaRLE.jl/ package directory using the dedicated scripts
##### environment (which pulls in BenchmarkTools):
#####
#####     julia --project=scripts scripts/size.jl
#####
##### Writes a GitHub-flavored Markdown report to scripts/size.md. Each row is
##### a different hypnogram-shaped scenario; size columns are the serialized
##### byte sizes for `lpcm`, `lpcm.zst`, `lpcm.rle`, `lpcm.rle.u16`, and
##### `lpcm.rle.u32`, and timing columns report median encode / decode time
##### measured by BenchmarkTools. Size ratios are relative to plain `lpcm`;
##### the smallest format per row is bolded.

using Onda
using OndaRLE
using OndaRLE: RLEFormat, Varint
using Random
using Printf
using BenchmarkTools

function hypnogram(; nch=1, n=900, runs_per_channel=30, alphabet=Int8(0):Int8(4),
                   seed=0)
    rng = MersenneTwister(seed)
    data = Matrix{Int8}(undef, nch, n)
    for ch in 1:nch
        boundaries = unique!(sort!(rand(rng, 1:n-1, max(runs_per_channel - 1, 0))))
        starts = vcat(1, boundaries .+ 1)
        ends = vcat(boundaries, n)
        prev = Int8(rand(rng, alphabet))
        for (s, e) in zip(starts, ends)
            v = Int8(rand(rng, alphabet))
            while v == prev && length(alphabet) > 1
                v = Int8(rand(rng, alphabet))
            end
            data[ch, s:e] .= v
            prev = v
        end
    end
    return data
end

function info_for(nch)
    return SamplesInfoV2(sensor_type="hypnogram",
                         channels=["c$i" for i in 1:nch],
                         sample_unit="stage",
                         sample_resolution_in_unit=1,
                         sample_offset_in_unit=0,
                         sample_type=Int8,
                         sample_rate=1/30)
end

const FORMATS = [
    ("lpcm",         info -> Onda.LPCMFormat(info)),
    ("lpcm.zst",     info -> Onda.LPCMZstFormat(info)),
    ("lpcm.rle",     info -> RLEFormat(info; count_encoding=Varint())),
    ("lpcm.rle.u16", info -> RLEFormat(info; count_encoding=UInt16)),
    ("lpcm.rle.u32", info -> RLEFormat(info; count_encoding=UInt32)),
]

const SCENARIOS = [
    (label="1ch  ×  900, 30 runs (typical sleep stage)",   kw=(; nch=1, n=900,  runs_per_channel=30)),
    (label="3ch  ×  900, 30 runs/ch (multi-channel)",      kw=(; nch=3, n=900,  runs_per_channel=30)),
    (label="1ch  ×  900,  5 runs (very long runs)",        kw=(; nch=1, n=900,  runs_per_channel=5)),
    (label="1ch  ×  900, 200 runs (choppy)",               kw=(; nch=1, n=900,  runs_per_channel=200)),
    (label="1ch  ×  900, 900 runs (no runs at all)",       kw=(; nch=1, n=900,  runs_per_channel=900)),
    (label="1ch  × 3600, 60 runs (long recording)",        kw=(; nch=1, n=3600, runs_per_channel=60)),
    (label="8ch  ×  900, 30 runs/ch (8-channel hypno)",    kw=(; nch=8, n=900,  runs_per_channel=30)),
    (label="1ch  × 86400, 200 runs (full-day, 1 Hz)",      kw=(; nch=1, n=86400, runs_per_channel=200)),
]

function format_size_cell(nbytes, baseline, is_smallest)
    ratio = baseline / nbytes
    text = nbytes == baseline ? @sprintf("%d B (1.0×)", nbytes) :
                                @sprintf("%d B (%.1f×)", nbytes, ratio)
    return is_smallest ? "**$(text)**" : text
end

function format_time_ns(t_ns)
    t_ns < 1_000             && return @sprintf("%.0f ns", t_ns)
    t_ns < 1_000_000         && return @sprintf("%.2f µs", t_ns / 1_000)
    t_ns < 1_000_000_000     && return @sprintf("%.2f ms", t_ns / 1_000_000)
    return @sprintf("%.2f s", t_ns / 1_000_000_000)
end

function bench_encode_decode(fmt, data)
    bytes = serialize_lpcm(fmt, data)
    enc = @benchmark serialize_lpcm($fmt, $data) seconds=1
    dec = @benchmark deserialize_lpcm($fmt, $bytes) seconds=1
    return (; nbytes=length(bytes),
              encode_ns=median(enc).time,
              decode_ns=median(dec).time)
end

function main(; output_path=joinpath(@__DIR__, "size.md"))
    n_formats = length(FORMATS)
    size_rows = Vector{Vector{String}}()
    encode_rows = Vector{Vector{String}}()
    decode_rows = Vector{Vector{String}}()

    for (si, s) in enumerate(SCENARIOS)
        @info "benchmarking" scenario=s.label progress="$si/$(length(SCENARIOS))"
        data = hypnogram(; s.kw...)
        info = info_for(s.kw.nch)
        results = [bench_encode_decode(build(info), data) for (_, build) in FORMATS]
        sizes = [r.nbytes for r in results]
        encs  = [r.encode_ns for r in results]
        decs  = [r.decode_ns for r in results]
        baseline = sizes[1]  # `lpcm` is the first column
        smallest_size = minimum(sizes)
        fastest_enc = minimum(encs)
        fastest_dec = minimum(decs)

        size_cells = String["`$(s.label)`"]
        enc_cells  = String["`$(s.label)`"]
        dec_cells  = String["`$(s.label)`"]
        for i in 1:n_formats
            push!(size_cells, format_size_cell(sizes[i], baseline, sizes[i] == smallest_size))
            enc_text = format_time_ns(encs[i])
            push!(enc_cells, encs[i] == fastest_enc ? "**$enc_text**" : enc_text)
            dec_text = format_time_ns(decs[i])
            push!(dec_cells, decs[i] == fastest_dec ? "**$dec_text**" : dec_text)
        end
        push!(size_rows, size_cells)
        push!(encode_rows, enc_cells)
        push!(decode_rows, dec_cells)
    end

    header = ["scenario"; ["`$name`" for (name, _) in FORMATS]]
    align = ["---"; fill("---:", n_formats)]

    function write_table(io, title, rows)
        println(io, "## ", title)
        println(io)
        println(io, "| ", join(header, " | "), " |")
        println(io, "| ", join(align, " | "), " |")
        for row in rows
            println(io, "| ", join(row, " | "), " |")
        end
        println(io)
    end

    open(output_path, "w") do io
        println(io, "# Onda hypnogram serialization: size & speed")
        println(io)
        println(io, "Encoded byte sizes and median encode / decode timings ",
                    "(via BenchmarkTools) for several hypnogram-shaped `Int8` ",
                    "matrices. Size ratios are relative to plain `lpcm`. The best ",
                    "value per row is **bolded** in each table. Generated by ",
                    "[`scripts/size.jl`](size.jl).")
        println(io)
        write_table(io, "Encoded size", size_rows)
        write_table(io, "Encode time (median)", encode_rows)
        write_table(io, "Decode time (median)", decode_rows)
        println(io, "## Notes")
        println(io)
        println(io, "- `lpcm.rle` (varint counts) wins on size for typical ",
                    "hypnograms with long runs and dominates the fixed-width ",
                    "`u16` / `u32` variants in every scenario tested — both on ",
                    "size and on speed.")
        println(io, "- When runs are short or absent (high-entropy data), ",
                    "`lpcm.zst` is more robust and RLE can actually inflate the ",
                    "payload.")
        println(io, "- `lpcm` is essentially free (a pure `reinterpret`); both ",
                    "RLE and zstd trade speed for size, but for typical ",
                    "hypnogram sizes the absolute encode/decode times are still ",
                    "in the microseconds.")
        println(io)
        println(io, "Timings are medians from BenchmarkTools `@benchmark` runs ",
                    "on a single host; absolute numbers will vary across ",
                    "machines, but relative ordering should be stable.")
    end
    println("wrote $output_path")
    return nothing
end

main()
