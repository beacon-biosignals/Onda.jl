using Test, Onda, Random, Dates

@testset "Serialization API ($(repr(extension)))" for (extension, options) in [(:lpcm, nothing),
                                                                               (Symbol("lpcm.zst"), Dict(:level => 2))]
    signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50.5, extension, options)
    samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50.5 * 10))))
    signal_serializer = serializer(signal)

    bytes = serialize_lpcm(samples.data, signal_serializer)
    io = IOBuffer()
    serialize_lpcm(io, samples.data, signal_serializer)
    seekstart(io)
    @test take!(io) == bytes

    @test deserialize_lpcm(bytes, signal_serializer) == samples.data
    @test deserialize_lpcm(bytes, signal_serializer, 99, 201) == view(samples.data, :, 100:300)
    @test deserialize_lpcm(IOBuffer(bytes), signal_serializer) == samples.data
    io = IOBuffer(bytes)
    @test deserialize_lpcm(io, signal_serializer, 49, 51) == view(samples.data, :, 50:100)

    callback, byte_offset, byte_count = deserialize_lpcm_callback(signal_serializer, 99, 201)
    if extension == :lpcm
        byte_range = (byte_offset + 1):(byte_offset + byte_count)
        @test callback(bytes[byte_range]) == view(samples.data, :, 100:300)
        @test bytes == reinterpret(UInt8, vec(samples.data))
        # XXX this is broken for LPCMZstd; see https://github.com/beacon-biosignals/Onda.jl/issues/40
        @test deserialize_lpcm(io, signal_serializer, 49, 51) == view(samples.data, :, 150:200)
    else
        @test ismissing(byte_offset) && ismissing(byte_count)
        @test callback(bytes) == view(samples.data, :, 100:300)
    end
end

@test_throws ArgumentError Onda.serializer_constructor_for_file_extension(Val(:extension))
@test_throws ErrorException Onda.register_file_extension_for_serializer(:extension, LPCM)
