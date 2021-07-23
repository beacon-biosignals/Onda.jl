@testset "LPCM (De)serialization API ($file_format)" for file_format in ("lpcm", "lpcm.zst")
    info = SamplesInfo(kind="kind", channels=["a", "b", "c"], sample_unit="unit",
                       sample_resolution_in_unit=0.25, sample_offset_in_unit=-0.5,
                       sample_type=Int16, sample_rate=50.5)
    samples = encode(Samples(rand(MersenneTwister(1), 3, Int(50.5 * 10)), info, false))
    fmt = format(file_format, info)
    @test_throws ArgumentError format(file_format * ".lol", info)

    bytes = serialize_lpcm(fmt, samples.data)
    @test bytes == serialize_lpcm(fmt, view(samples.data, :, :))
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

    io = IOBuffer()
    for _ in 1:2 # test `io` reuse for serialization
        stream = serializing_lpcm_stream(fmt, io)
        serialize_lpcm(stream, samples.data)
        @test finalize_lpcm_stream(stream)
    end
    seekstart(io)
    stream = deserializing_lpcm_stream(fmt, io)
    @test deserialize_lpcm(stream) == hcat(samples.data, samples.data)
    finalize_lpcm_stream(stream) && close(io)

    io = IOBuffer(bytes)
    stream = deserializing_lpcm_stream(fmt, io)
    @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 50:100)
    @test deserialize_lpcm(stream, 49, 51) == view(samples.data, :, 150:200)
    @test deserialize_lpcm(stream, 9) == view(samples.data, :, 210:size(samples.data, 2))
    finalize_lpcm_stream(stream) && close(io)

    callback, byte_offset, byte_count = deserialize_lpcm_callback(fmt, 99, 201)
    if file_format == "lpcm"
        byte_range = (byte_offset + 1):(byte_offset + byte_count)
        @test callback(bytes[byte_range]) == view(samples.data, :, 100:300)
        @test bytes == reinterpret(UInt8, vec(samples.data))
    else
        @test ismissing(byte_offset) && ismissing(byte_count)
        @test callback(bytes) == view(samples.data, :, 100:300)
    end
end