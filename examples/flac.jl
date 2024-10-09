# This file demonstrates an implementation of FLAC support for Onda.jl.

using Onda, FLAC_jll, Test, Random, Dates

#####
##### FLACFormat
#####

"""
     FLACFormat(lpcm::LPCMFormat; sample_rate, level=5)
     FLACFormat(info::SamplesInfo; level=5)

Return a `FLACFormat<:AbstractLPCMFormat` instance that represents the
FLAC format corresponding to signals whose `file_format` field is `"flac"`.

The `sample_rate` keyword argument corresponds to `flac`'s `--sample-rate` flag,
while `level` corresponds to `flac`'s `--compression-level` flag.

Note that FLAC is only applicable for `info` where `1 <= channel_count(info) <= 8`
and `sizeof(info.sample_type) in (1, 2)`.

See https://xiph.org/flac/ for details about FLAC.

See also: [`Zstd`](@ref)
"""
struct FLACFormat{S} <: Onda.AbstractLPCMFormat
    lpcm::LPCMFormat{S}
    sample_rate::Int
    level::Int
    function FLACFormat(lpcm::LPCMFormat{S}; sample_rate, level=5) where {S}
        sizeof(S) in (1, 2) || throw(ArgumentError("bit depth must be 8 or 16"))
        1 <= lpcm.channel_count <= 8 || throw(ArgumentError("channel count must be between 1 and 8"))
        return new{S}(lpcm, sample_rate, level)
    end
end

FLACFormat(info; kwargs...) = FLACFormat(LPCMFormat(info); sample_rate=info.sample_rate, kwargs...)

Onda.register_lpcm_format!(file_format -> file_format == "flac" ? FLACFormat : nothing)

Onda.file_format_string(::FLACFormat) = "flac"

function flac_raw_specification_flags(format::FLACFormat{S}) where {S}
    return (level="--compression-level-$(format.level)",
            endian="--endian=little",
            channels="--channels=$(format.lpcm.channel_count)",
            bps="--bps=$(sizeof(S) * 8)",
            sample_rate="--sample-rate=$(format.sample_rate)",
            is_signed=string("--sign=", S <: Signed ? "signed" : "unsigned"))
end

struct FLACStream{L<:Onda.LPCMStream} <: AbstractLPCMStream
    stream::L
end

function Onda.deserializing_lpcm_stream(format::FLACFormat, io)
    flags = flac_raw_specification_flags(format)
    cmd = flac() do flac_path
        return open(`$flac_path - --totally-silent -d --force-raw-format $(flags.endian) $(flags.is_signed)`, io)
    end
    return FLACStream(Onda.LPCMStream(format.lpcm, cmd))
end

function Onda.serializing_lpcm_stream(format::FLACFormat, io)
    flags = flac_raw_specification_flags(format)
    cmd = flac() do flac_path
        return open(`$flac_path --totally-silent $(flags) -`, io; write=true)
    end
    return FLACStream(Onda.LPCMStream(format.lpcm, cmd))
end

function Onda.finalize_lpcm_stream(stream::FLACStream)
    close(stream.stream.io)
    wait(stream.stream.io)
    return true
end

Onda.deserialize_lpcm(stream::FLACStream, args...) = deserialize_lpcm(stream.stream, args...)

Onda.serialize_lpcm(stream::FLACStream, args...) = serialize_lpcm(stream.stream, args...)

function Onda.deserialize_lpcm(format::FLACFormat, bytes, args...)
    stream = deserializing_lpcm_stream(format, IOBuffer(bytes))
    results = deserialize_lpcm(stream, args...)
    finalize_lpcm_stream(stream)
    return results
end

function Onda.serialize_lpcm(format::FLACFormat, samples::AbstractMatrix)
    io = IOBuffer()
    stream = serializing_lpcm_stream(format, io)
    serialize_lpcm(stream, samples)
    finalize_lpcm_stream(stream)
    return take!(io)
end

#####
##### tests
#####

saws(info, duration) = [(j + i) % 100 * info.sample_resolution_in_unit for
                        i in 1:channel_count(info), j in 1:sample_count(info, duration)]

if VERSION >= v"1.1.0"
    @testset "FLAC example" begin
        info = SamplesInfoV2(; sensor_type="test", channels=["a", "b", "c"],
                             sample_unit="unit",
                             sample_resolution_in_unit=0.25,
                             sample_offset_in_unit=-0.5,
                             sample_type=Int16,
                             sample_rate=50)
        data = saws(info, Minute(3))
        samples = encode(Samples(data, info, false))
        fmt = FLACFormat(info)

        bytes = serialize_lpcm(fmt, samples.data)
        @test deserialize_lpcm(fmt, bytes) == samples.data
        @test deserialize_lpcm(fmt, bytes, 99) == view(samples.data, :, 100:size(samples.data, 2))
        @test deserialize_lpcm(fmt, bytes, 99, 201) == view(samples.data, :, 100:300)

        io = IOBuffer()
        stream = serializing_lpcm_stream(fmt, io)
        serialize_lpcm(stream, samples.data)
        @test finalize_lpcm_stream(stream)
        seekstart(io)
        stream = deserializing_lpcm_stream(fmt, io)
        @test deserialize_lpcm(stream) == samples.data
        finalize_lpcm_stream(stream) && close(io)

        io = IOBuffer(bytes)
        stream = deserializing_lpcm_stream(fmt, io)
        @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 50:100)
        @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 150:200)
        @test deserialize_lpcm(stream, 9) == view(samples.data, :, 210:size(samples.data, 2))
        finalize_lpcm_stream(stream) && close(io)
    end
else
    @warn "This example may be broken on Julia versions lower than v1.1 due to https://github.com/JuliaLang/julia/issues/33117"
end
