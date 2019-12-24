using Test, Onda, Random

@testset "$(repr(name)) serializer" for (name, options) in [(:lpcm, nothing),
                                                        (Symbol("lpcm.zst"), Dict(:level => 2))]
    signal = Signal([:a, :b, :c], :unit, 0.25, Int16, 50, name, options)
    samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, 50 * 10))).data
    s = serializer(signal)
    bytes = serialize_lpcm(samples, s)
    name == :lpcm && @test bytes == reinterpret(UInt8, vec(samples))
    @test deserialize_lpcm(bytes, s) == samples
    @test deserialize_lpcm(IOBuffer(bytes), s) == samples
    io = IOBuffer(); serialize_lpcm(io, samples, s); seekstart(io)
    @test take!(io) == bytes
end
