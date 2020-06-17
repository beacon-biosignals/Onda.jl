using Test, Onda, Random, Dates, UUIDs

# NOTE: `read_recordings_file` and `write_recordings_file` are technically
# part of the Paths API, but are tested in `test/dataset.jl` for the sake
# of convenience.

@testset "Paths API ($(repr(extension)))" for (extension, options) in [(:lpcm, nothing),
                                                                       (Symbol("lpcm.zst"), Dict(:level => 2))]
    signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50.5, extension, options)
    samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50.5 * 10))))
    signal_serializer = serializer(signal)
    uuid = uuid4()

    @test samples_path("test", uuid) == joinpath("test", "samples", string(uuid))
    @test samples_path("test", uuid, :eeg, :lpcm) == joinpath("test", "samples", string(uuid), "eeg.lpcm")

    mktempdir() do root
        file_path = joinpath(root, "test.$(extension)")
        write_samples(file_path, samples)
        span = TimeSpan(Second(3), Second(4))
        test = read_samples(file_path, signal)
        @test test.data == samples.data
        @test test.signal == samples.signal
        test = read_samples(file_path, signal, span)
        @test test.data == view(samples, :, span).data
        @test test.signal == samples.signal
        write_lpcm(file_path, samples.data, signal_serializer)
        @test read_lpcm(file_path, signal_serializer) == samples.data
        @test read_lpcm(file_path, signal_serializer, 99, 201) == view(samples.data, :, 100:300)
    end
end
