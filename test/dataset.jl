using Test, Onda, Dates, MsgPack

@testset "round trip" begin
    mktempdir() do root
        # generate a test dataset
        dataset = Dataset(joinpath(root, "test.onda"); create=true)
        @test dataset isa Dataset
        @test isdir(dataset.path)
        @test isdir(joinpath(dataset.path, "samples"))
        duration_in_seconds = Second(10)
        duration_in_nanoseconds = Nanosecond(duration_in_seconds)
        uuid, recording = create_recording!(dataset, duration_in_nanoseconds)
        Ts = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64)
        signals = Dict(Symbol(:x, i) => Signal(Symbol.([:a, :b, :c], i),
                                               Symbol(:unit, i), 0.25, T,
                                               100, Symbol("lpcm.zst"), nothing)
                       for (i, T) in enumerate(Ts))
        samples = Dict(k => Samples(v, true, rand(v.sample_type, 3, 100 * 10))
                       for (k, v) in signals)
        for (name, s) in samples
            @test channel_count(s) == length(s.signal.channel_names)
            @test channel_count(s.signal) == length(s.signal.channel_names)
            @test sample_count(s) == size(s.data, 2)
            @test encode(s) === s
            tmp = similar(s.data)
            encode!(tmp, s)
            @test tmp == s.data
            d = decode(s)
            @test decode(d) === d
            tmp = similar(d.data)
            decode!(tmp, d)
            @test tmp == d.data
            tmp = similar(d.data)
            decode!(tmp, s)
            @test tmp == d.data
            tmp = similar(d.data)
            decode!(tmp, s.signal.sample_resolution_in_unit, s.data)
            @test tmp == d.data
            @test d.data == (s.data .* s.signal.sample_resolution_in_unit)
            if sizeof(s.signal.sample_type) >= 8
                # decoding from 64-bit to floating point is fairly lossy
                tmp = similar(s.data)
                @test isapprox(encode(d, nothing).data, s.data, rtol = 10)
                encode!(tmp, d, nothing)
                @test isapprox(tmp, s.data, rtol = 10)
                @test isapprox(encode(d, missing).data, s.data, rtol = 10)
                encode!(tmp, d, missing)
                @test isapprox(tmp, s.data, rtol = 10)
            else
                tmp = similar(s.data)
                encode!(tmp, d, nothing)
                @test tmp == s.data
                @test encode(d, nothing).data == s.data
                encode!(tmp, d, missing)
                @test isapprox(tmp, s.data, rtol = 1)
                @test isapprox(encode(d, missing).data, s.data, rtol = 1)
            end
            chs = s.signal.channel_names
            i = 93
            @test s[:, i].data == s.data[:, i:i]
            t = Onda.time_from_index(s.signal.sample_rate, i)
            t2 = t + Nanosecond(Second(3))
            j = Onda.index_from_time(s.signal.sample_rate, t2) - 1
            for ch_inds in (:, 1:2, 2:3, 1:3, [3,1], [2,3,1], [1,2,3])
                @test s[chs[ch_inds], t].data == s[ch_inds, i].data
                @test s[chs[ch_inds], TimeSpan(t, t2)].data == s.data[ch_inds, i:j]
                @test s[chs[ch_inds], i:j].data == s.data[ch_inds, i:j]
                @test s[ch_inds, t].data == s[ch_inds, i].data
                @test s[ch_inds, TimeSpan(t, t2)].data == s.data[ch_inds, i:j]
                @test s[ch_inds, i:j].data == s.data[ch_inds, i:j]
            end
            @test size(s[:, TimeSpan(0, Second(1))].data, 2) == s.signal.sample_rate
            for i in 1:length(chs)
                @test channel(s, chs[i]) == i
                @test channel(s, i) == chs[i]
                @test channel(s.signal, chs[i]) == i
                @test channel(s.signal, i) == chs[i]
            end
            @test duration(s) == Nanosecond((100 * 10) * (1_000_000_000) // 100)
            @test s[:, TimeSpan(0, duration(s))].data == s.data
            store!(dataset, uuid, name, s)
        end
        save_recordings_file(dataset)

        # read back in the test dataset, add some annotations
        old_dataset = dataset
        dataset = Dataset(joinpath(root, "test.onda"))
        @test length(dataset.recordings) == 1
        uuid, recording = first(dataset.recordings)
        x1 = load(dataset, uuid, :x1)
        @test x1.signal == signals[:x1]
        xs = load(dataset, uuid, (:x3, :x2))
        @test xs[:x3].signal == signals[:x3]
        @test xs[:x2].signal == signals[:x2]
        xs = load(dataset, uuid)
        span = TimeSpan(Second(1), Second(2))
        xs_span = load(dataset, uuid, span)
        for (name, s) in samples
            xi = xs[name]
            @test xi.signal == signals[name]
            @test xi.encoded
            @test xi.data == s.data
            @test xi[:, span].data == xs_span[name].data
        end
        for i in 1:3
            annotate!(recording, Annotation("key_$i", "value_$i", Nanosecond(i), Nanosecond(i + rand(1:1000000))))
        end
        save_recordings_file(dataset)

        # read back in annotations
        old_uuid = uuid
        old_recording = recording
        old_dataset = dataset
        dataset = Dataset(joinpath(root, "test.onda"))
        uuid, recording = first(dataset.recordings)
        @test old_recording == recording
        delete!(dataset.recordings, uuid)
        uuid, recording = create_recording!(dataset, old_recording.duration_in_nanoseconds)
        foreach(x -> annotate!(recording, x), old_recording.annotations)
        foreach(x -> store!(dataset, uuid, x, load(old_dataset, old_uuid, x)), keys(old_recording.signals))
        merge!(dataset, old_dataset, only_recordings=true)
        @test length(dataset.recordings) == 2
        r1 = dataset.recordings[old_uuid]
        @test r1 == old_recording
        r2 = dataset.recordings[uuid]
        @test r2 == recording
        @test old_uuid != uuid
        @test r1.duration_in_nanoseconds == r2.duration_in_nanoseconds
        @test r1.signals == r2.signals
        @test r1.annotations == r2.annotations
        @test r1.custom == r2.custom

        new_duration = r2.duration_in_nanoseconds + Nanosecond(1)
        r3 = set_duration!(dataset, uuid, new_duration)
        @test r3.signals === r2.signals
        @test r3.annotations === r2.annotations
        @test r3.custom === r2.custom
        @test r3.duration_in_nanoseconds === new_duration
        @test dataset.recordings[uuid] === r3
        set_duration!(dataset, uuid, r2.duration_in_nanoseconds)

        r = dataset.recordings[uuid]
        original_signals_length = length(r.signals)
        signal_name, signal = first(r.signals)
        signal_samples = load(dataset, uuid, signal_name)
        signal_samples_path = samples_path(dataset, uuid, signal_name)
        delete!(dataset, uuid, signal_name)
        @test r === dataset.recordings[uuid]
        @test length(r.signals) == (original_signals_length - 1)
        @test !haskey(r.signals, signal_name)
        @test !isfile(signal_samples_path)
        store!(dataset, uuid, signal_name, signal_samples)

        # read back everything, but without assuming an order on the metadata
        dataset = Dataset(joinpath(root, "test.onda"))
        Onda.write_recordings_file(dataset.path,
                                   Onda.Header(dataset.header.onda_format_version, false),
                                   dataset.recordings)
        dataset = Dataset(joinpath(root, "test.onda"))
        @test Dict(old_uuid => old_recording) == dataset.recordings
        delete!(dataset, old_uuid)
        save_recordings_file(dataset)

        # read back the dataset that should now be empty
        dataset = Dataset(joinpath(root, "test.onda"))
        @test isempty(dataset.recordings)
        @test !isdir(joinpath(dataset.path, "samples", string(old_uuid)))
    end
end

@testset "Error conditions" begin
    mktempdir() do root
        @test_throws ArgumentError Dataset(joinpath(root, "doesnt_end_with_onda"); create=true)
        mkdir(joinpath(root, "i_exist.onda"))
        touch(joinpath(root, "i_exist.onda", "memes"))
        @test_throws ArgumentError Dataset(joinpath(root, "i_exist.onda"); create=true)
        mkdir(joinpath(root, "no_samples_dir.onda"))
        @test_throws ArgumentError Dataset(joinpath(root, "no_samples_dir.onda"); create=false)

        dataset = Dataset(joinpath(root, "okay.onda"); create=true)
        duration = Nanosecond(Second(10))
        uuid, recording = create_recording!(dataset, duration)
        signal = Signal([:a], :mv, 0.25, Int8, 100, Symbol("lpcm.zst"), nothing)
        @test_throws DimensionMismatch Samples(signal, true, rand(Int8, 2, 10))
        @test_throws ArgumentError Samples(signal, true, rand(Float32, 1, 10))
        samples = Samples(signal, true, rand(Int8, 1, 10 * 100))
        @test_throws ArgumentError store!(dataset, uuid, Symbol("***HI***"), samples)
        store!(dataset, uuid, :name_okay, samples)
        @test_throws ArgumentError store!(dataset, uuid, :name_okay, samples; overwrite=false)

        @test_throws ArgumentError Annotation("hi", "there", Nanosecond(20), Nanosecond(4))

        mkdir(joinpath(root, "other.onda"))
        other = Dataset(joinpath(root, "other.onda"); create=true)  # Using existing empty directory
        create_recording!(other, duration, nothing, uuid)
        @test_throws ArgumentError create_recording!(other, duration, nothing, uuid)
        store!(other, uuid, :cool_stuff, samples)
        @test_throws ErrorException merge!(dataset, other; only_recordings=false)
        @test_throws ArgumentError merge!(dataset, other; only_recordings=true)
    end
end
