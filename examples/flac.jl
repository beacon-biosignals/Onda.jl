# This file demonstrates an implementation of FLAC support for Onda.jl. Note
# that it's a naive implementation - it just shells out and assumes you have
# the `flac` command line utility installed and available on your system.

using Onda, Test, Random, Dates

#####
##### FLAC
#####

"""
     FLAC(lpcm::LPCM; sample_rate, level=5)
     FLAC(signal::Signal; level=5)

Return a `FLAC<:AbstractLPCMFormat` instance that represents the
FLAC format assumed for sample data files with the ".flac" extension.

The `sample_rate` keyword argument corresponds to `flac`'s `--sample-rate` flag,
while `level` corresponds to `flac`'s `--compression-level` flag.

Note that FLAC is only applicable for signals where `1 <= signal.channel_count <= 8`
and `sizeof(signal.sample_type) in (1, 2)`. The corresponding `signal.file_options`
value may be either `nothing` or `Dict(:level => i)` where `0 <= i <= 8`.

See https://xiph.org/flac/ for details about FLAC.

See also: [`Zstd`](@ref)
"""
struct FLAC{S} <: Onda.AbstractLPCMFormat
    lpcm::LPCM{S}
    sample_rate::Int
    level::Int
    function FLAC(lpcm::LPCM{S}; sample_rate, level=5) where {S}
        sizeof(S) in (1, 2) || throw(ArgumentError("bit depth must be 8 or 16"))
        1 <= lpcm.channel_count <= 8 || throw(ArgumentError("channel count must be between 1 and 8"))
        return new{S}(lpcm, sample_rate, level)
    end
end

FLAC(signal::Signal; kwargs...) = FLAC(LPCM(signal); sample_rate=signal.sample_rate,
                                       kwargs...)

Onda.file_format_constructor(::Val{:flac}) = FLAC

function flac_raw_specification_flags(serializer::FLAC{S}) where {S}
    return (level="--compression-level-$(serializer.level)",
            endian="--endian=little",
            channels="--channels=$(serializer.lpcm.channel_count)",
            bps="--bps=$(sizeof(S) * 8)",
            sample_rate="--sample-rate=$(serializer.sample_rate)",
            is_signed=string("--sign=", S <: Signed ? "signed" : "unsigned"))
end

struct FLACStream{L<:Onda.LPCMStream} <: AbstractLPCMStream
    stream::L
end

function Onda.deserializing_lpcm_stream(format::FLAC, io)
    flags = flac_raw_specification_flags(format)
    cmd = open(`flac - --totally-silent -d --force-raw-format $(flags.endian) $(flags.is_signed)`, io)
    return FLACStream(Onda.LPCMStream(format.lpcm, cmd))
end

function Onda.serializing_lpcm_stream(format::FLAC, io)
    flags = flac_raw_specification_flags(format)
    cmd = open(`flac --totally-silent $(flags) -`, io; write=true)
    return FLACStream(Onda.LPCMStream(format.lpcm, cmd))
end

function Onda.finalize_lpcm_stream(stream::FLACStream)
    close(stream.stream.io)
    wait(stream.stream.io)
    return true
end

Onda.deserialize_lpcm(stream::FLACStream, args...) = deserialize_lpcm(stream.stream, args...)

Onda.serialize_lpcm(stream::FLACStream, args...) = serialize_lpcm(stream.stream, args...)

function Onda.deserialize_lpcm(format::FLAC, bytes, args...)
    stream = deserializing_lpcm_stream(format, IOBuffer(bytes))
    results = deserialize_lpcm(stream, args...)
    finalize_lpcm_stream(stream)
    return results
end

function Onda.serialize_lpcm(format::FLAC, samples::AbstractMatrix)
    io = IOBuffer()
    stream = serializing_lpcm_stream(format, io)
    serialize_lpcm(stream, samples)
    finalize_lpcm_stream(stream)
    return take!(io)
end

#####
##### tests
#####

if VERSION >= v"1.1.0"
    @testset "FLAC example" begin
        signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50, :flac, Dict(:level => 2))
        samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50 * 10))))
        signal_format = format(signal)

        bytes = serialize_lpcm(signal_format, samples.data)
        @test deserialize_lpcm(signal_format, bytes) == samples.data
        @test deserialize_lpcm(signal_format, bytes, 99) == view(samples.data, :, 100:size(samples.data, 2))
        @test deserialize_lpcm(signal_format, bytes, 99, 201) == view(samples.data, :, 100:300)

        io = IOBuffer()
        stream = serializing_lpcm_stream(signal_format, io)
        serialize_lpcm(stream, samples.data)
        @test finalize_lpcm_stream(stream)
        seekstart(io)
        stream = deserializing_lpcm_stream(signal_format, io)
        @test deserialize_lpcm(stream) == samples.data
        finalize_lpcm_stream(stream) && close(io)

        io = IOBuffer(bytes)
        stream = deserializing_lpcm_stream(signal_format, io)
        @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 50:100)
        @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 150:200)
        @test deserialize_lpcm(stream, 9) == view(samples.data, :, 210:size(samples.data, 2))
        finalize_lpcm_stream(stream) && close(io)
    end
else
    @warn "This example may be broken on Julia versions lower than v1.1 due to https://github.com/JuliaLang/julia/issues/33117"
end
