using Onda
using OndaRLE
using OndaRLE: RLEFormat, Varint
using Random
using Test
using Dates: Nanosecond
using TimeSpans: TimeSpan

function _hypnogram_sample(rng, nch, T; n=900, runs_per_channel=30, alphabet=Int8(0):Int8(4))
    data = Matrix{T}(undef, nch, n)
    for ch in 1:nch
        boundaries = sort!(rand(rng, 1:n-1, runs_per_channel - 1))
        boundaries = unique!(boundaries)
        starts = vcat(1, boundaries .+ 1)
        ends = vcat(boundaries, n)
        prev = T(rand(rng, alphabet))
        for (s, e) in zip(starts, ends)
            v = T(rand(rng, alphabet))
            while v == prev && length(alphabet) > 1
                v = T(rand(rng, alphabet))
            end
            for t in s:e
                data[ch, t] = v
            end
            prev = v
        end
    end
    return data
end

@testset "OndaRLE" begin
    info = SamplesInfoV2(sensor_type="hypnogram",
                         channels=["stage"],
                         sample_unit="stage",
                         sample_resolution_in_unit=1,
                         sample_offset_in_unit=0,
                         sample_type=Int8,
                         sample_rate=1/30)
    info3 = SamplesInfoV2(sensor_type="hypnogram",
                          channels=["a", "b", "c"],
                          sample_unit="stage",
                          sample_resolution_in_unit=1,
                          sample_offset_in_unit=0,
                          sample_type=Int8,
                          sample_rate=1/30)

    @testset "registration ($file_format)" for (file_format, encoding) in (("lpcm.rle", Varint()),
                                                                          ("lpcm.rle.u16", UInt16),
                                                                          ("lpcm.rle.u32", UInt32))
        fmt = Onda.format(file_format, info)
        @test fmt isa RLEFormat
        @test fmt.count_encoding === encoding
        @test Onda.file_format_string(fmt) == file_format
    end

    @test_throws ArgumentError Onda.format("lpcm.rle.lol", info)

    @testset "round-trip ($encoding, nch=$nch)" for encoding in (Varint(), UInt16, UInt32),
                                                     nch in (1, 3)
        rng = MersenneTwister(100 + nch)
        info_n = nch == 1 ? info : info3
        data = _hypnogram_sample(rng, nch, Int8)
        fmt = RLEFormat(info_n; count_encoding=encoding)

        bytes = serialize_lpcm(fmt, data)
        @test bytes == serialize_lpcm(fmt, view(data, :, :))
        @test deserialize_lpcm(fmt, bytes) == data
        @test deserialize_lpcm(fmt, bytes, 99) == view(data, :, 100:size(data, 2))
        @test deserialize_lpcm(fmt, bytes, 99, 201) == view(data, :, 100:300)

        callback, byte_offset, byte_count = Onda.deserialize_lpcm_callback(fmt, 99, 201)
        @test ismissing(byte_offset) && ismissing(byte_count)
        @test callback(bytes) == view(data, :, 100:300)
    end

    @testset "round-trip random Int8 (encoding=$encoding)" for encoding in (Varint(), UInt16, UInt32)
        rng = MersenneTwister(42)
        data = rand(rng, Int8, 3, 200)
        fmt = RLEFormat(info3; count_encoding=encoding)
        bytes = serialize_lpcm(fmt, data)
        @test deserialize_lpcm(fmt, bytes) == data
    end

    @testset "split runs at fixed-width cap (UInt16)" begin
        info1 = SamplesInfoV2(sensor_type="x", channels=["a"], sample_unit="u",
                              sample_resolution_in_unit=1, sample_offset_in_unit=0,
                              sample_type=Int8, sample_rate=1)
        data = fill(Int8(7), 1, 100_000)  # > 65535
        fmt = RLEFormat(info1; count_encoding=UInt16)
        bytes = serialize_lpcm(fmt, data)
        @test deserialize_lpcm(fmt, bytes) == data
    end

    @testset "stream API single write" begin
        rng = MersenneTwister(1)
        data = _hypnogram_sample(rng, 3, Int8)
        fmt = RLEFormat(info3; count_encoding=Varint())
        io = IOBuffer()
        stream = serializing_lpcm_stream(fmt, io)
        serialize_lpcm(stream, data)
        @test finalize_lpcm_stream(stream)
        seekstart(io)
        stream = deserializing_lpcm_stream(fmt, io)
        @test deserialize_lpcm(stream) == data
        finalize_lpcm_stream(stream) && close(io)
    end

    @testset "validation" begin
        fmt = RLEFormat(info3; count_encoding=Varint())
        @test_throws ArgumentError serialize_lpcm(fmt, rand(Int8, 2, 100))   # wrong nch
        @test_throws ArgumentError serialize_lpcm(fmt, rand(Int16, 3, 100))  # wrong eltype
    end

    @testset "Onda.store / Onda.load round-trip ($file_format)" for file_format in ("lpcm.rle", "lpcm.rle.u16", "lpcm.rle.u32")
        rng = MersenneTwister(11)
        data = _hypnogram_sample(rng, 3, Int8)
        samples = Samples(data, info3, true)
        mktempdir() do dir
            path = joinpath(dir, "hypno." * file_format)
            Onda.store(path, file_format, samples)
            loaded = Onda.load(path, file_format, info3; encoded=true)
            @test loaded.data == data
            @test loaded.info == info3

            # span-based load: returns timesteps 100:300 (inclusive, 1-indexed)
            sub = Onda.load(path, file_format, info3,
                            TimeSpan(round(Int, (99 / info3.sample_rate) * 1e9),
                                     round(Int, (300 / info3.sample_rate) * 1e9));
                            encoded=true)
            @test sub.data == view(data, :, 100:300)
        end
    end

    @testset "Onda.store / Onda.load via SignalV2" begin
        rng = MersenneTwister(12)
        data = _hypnogram_sample(rng, 3, Int8)
        samples = Samples(data, info3, true)
        recording = Base.UUID("00000000-0000-0000-0000-000000000001")
        mktempdir() do dir
            path = joinpath(dir, "hypno.lpcm.rle")
            signal = Onda.store(path, "lpcm.rle", samples, recording, Nanosecond(0))
            @test signal.file_format == "lpcm.rle"
            loaded = Onda.load(signal; encoded=true)
            @test loaded.data == data
        end
    end

    @testset "compression ratio vs LPCMFormat" begin
        rng = MersenneTwister(7)
        data = _hypnogram_sample(rng, 3, Int8; n=900, runs_per_channel=30)
        rle = serialize_lpcm(RLEFormat(info3), data)
        plain = serialize_lpcm(Onda.LPCMFormat(info3), data)
        @test length(rle) * 5 < length(plain)
        @info "OndaRLE compression" rle_bytes=length(rle) lpcm_bytes=length(plain) ratio=length(plain)/length(rle)
    end
end
