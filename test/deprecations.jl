using Test, Onda, UUIDs, Random, Dates

@testset "deprecations" begin
    mktempdir() do path
        dataset = Dataset(path)
        uuid = uuid4()
        @test samples_path(dataset, uuid, :eeg, :lpcm) == samples_path(path, uuid, :eeg, :lpcm)
        signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50.5, :lpcm, nothing)
        samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50.5 * 10))))
        span = TimeSpan(Second(1), Second(2))
        data_path = samples_path(path, uuid, :eeg, :lpcm)
        store_samples!(data_path, samples)
        write_samples(data_path * "2", samples)
        @test load_samples(data_path, signal).data == read_samples(data_path, signal).data
        @test load_samples(data_path, signal, span).data == read_samples(data_path, signal, span).data
        @test read_samples(data_path, signal).data == read_samples(data_path * "2", signal).data
        save_recordings_file(dataset)
        recordings_file_path = joinpath(path, Onda.RECORDINGS_FILE_NAME)
        recordings_file_bytes = read(recordings_file_path)
        @test read_recordings_msgpack_zst(recordings_file_path) == read_recordings_file(recordings_file_path)
        @test read_recordings_msgpack_zst(recordings_file_bytes) == deserialize_recordings_msgpack_zst(recordings_file_bytes)
        write_recordings_msgpack_zst(recordings_file_path * "2", dataset.header, dataset.recordings)
        @test read(recordings_file_path * "2") == recordings_file_bytes
        @test write_recordings_msgpack_zst(dataset.header, dataset.recordings) == recordings_file_bytes
        @test Dataset(path; create=false).recordings == load(path).recordings
        @test Dataset(path; create=true).recordings == load(path).recordings
    end
end

@testset "Serialization API deprecations for ($(repr(extension)))" for (extension, options) in
                                                                   [(:lpcm, nothing), (Symbol("lpcm.zst"), Dict(:level => 2))]
    signal = Signal([:a, :b, :c], Nanosecond(0), Nanosecond(0), :unit, 0.25, -0.5, Int16, 50.5, extension, options)
    samples = encode(Samples(signal, false, rand(MersenneTwister(1), 3, Int(50.5 * 10))))
    signal_format = serializer(signal)

    bytes = serialize_lpcm(samples.data, signal_format)
    io = IOBuffer()
    serialize_lpcm(io, samples.data, signal_format)
    seekstart(io)
    @test take!(io) == bytes

    @test deserialize_lpcm(bytes, signal_format) == samples.data
    @test deserialize_lpcm(bytes, signal_format, 99) == view(samples.data, :, 100:size(samples.data, 2))
    @test deserialize_lpcm(bytes, signal_format, 99, 201) == view(samples.data, :, 100:300)
    @test deserialize_lpcm(IOBuffer(bytes), signal_format) == samples.data
    io = IOBuffer(bytes)
    @test deserialize_lpcm(io, signal_format, 49, 51) == view(samples.data, :, 50:100)
    callback, byte_offset, byte_count = deserialize_lpcm_callback(signal_format, 99, 201)
    if extension == :lpcm
        byte_range = (byte_offset + 1):(byte_offset + byte_count)
        @test callback(bytes[byte_range]) == view(samples.data, :, 100:300)
        @test bytes == reinterpret(UInt8, vec(samples.data))
        @test deserialize_lpcm(io, signal_format, 49, 51) == view(samples.data, :, 150:200)
    else
        @test ismissing(byte_offset) && ismissing(byte_count)
        @test callback(bytes) == view(samples.data, :, 100:300)
    end
end

@test_throws ErrorException Onda.zstd_compress(identity, IOBuffer())
@test_throws ErrorException Onda.zstd_decompress(identity, IOBuffer())
