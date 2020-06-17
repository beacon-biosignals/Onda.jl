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

    if extension == :lpcm
        # XXX this is broken for LPCMZstd; see https://github.com/beacon-biosignals/Onda.jl/issues/40
        @test deserialize_lpcm(io, signal_serializer, 49, 51) == view(samples.data, :, 150:200)
    end

    extension == :lpcm && @test bytes == reinterpret(UInt8, vec(samples.data))

    # TODO test deserialize_lpcm_callback(signal_serializer, samples_offset, samples_count)
end

@test_throws ArgumentError Onda.serializer_constructor_for_file_extension(Val(:extension))
@test_throws ErrorException Onda.register_file_extension_for_serializer(:extension, LPCM)
