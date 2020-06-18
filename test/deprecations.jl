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
