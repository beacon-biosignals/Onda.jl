using Test, Onda, Random, Dates

@testset "Serialization API ($(repr(extension)))" for (extension, options) in [(:lpcm, nothing),
                                                                               (Symbol("lpcm.zst"), Dict(:level => 2))]
    signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50.5, extension, options)
    samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50.5 * 10))))
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

    callback, byte_offset, byte_count = deserialize_lpcm_callback(signal_format, 99, 201)
    if extension == :lpcm
        byte_range = (byte_offset + 1):(byte_offset + byte_count)
        @test callback(bytes[byte_range]) == view(samples.data, :, 100:300)
        @test bytes == reinterpret(UInt8, vec(samples.data))
    else
        @test ismissing(byte_offset) && ismissing(byte_count)
        @test callback(bytes) == view(samples.data, :, 100:300)
    end
end

@test_throws ArgumentError Onda.format_constructor_for_file_extension(Val(:extension))
