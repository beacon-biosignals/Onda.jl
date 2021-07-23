@testset "`Samples` API" begin
    root = mktempdir()
    signals = Signal[]
    possible_recordings = (uuid4(), uuid4(), uuid4())
    expected_sample_types = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64)
    expected_parameters = [(recording=rand(possible_recordings),
                            file_path=joinpath(root, "x_$(i)_file"),
                            file_format=rand(("lpcm", "lpcm.zst")),
                            kind="x_$i",
                            channels=["a_$i", "b_$i", "c_$i"],
                            sample_unit="unit_$i",
                            sample_resolution_in_unit=rand((0.25, 1)),
                            sample_offset_in_unit=rand((-0.25, 0.25)),
                            sample_type=expected_sample_types[i],
                            sample_rate=rand((128, 50.5)),
                            start=Second(rand(0:30))) for i in 1:length(expected_sample_types)]
    for params in expected_parameters
        info = Onda.extract_samples_info(params)
        data = rand(params.sample_type, 3, sample_count(info, Second(rand(1:15))))
        samples = Samples(data, info, true)
        start = Second(rand(0:30))
        signal = store(params.file_path, params.file_format, samples, params.recording, params.start)
        push!(signals, signal)
    end
    for (expected, signal) in zip(expected_parameters, signals)
        expected_info = Onda.extract_samples_info(expected)
        for encoded in (false, true)
            s = load(signal; encoded)
            s1 = load(expected.file_path, expected.file_format, expected_info; encoded)
            s2 = load(expected.file_path, Onda.format(expected.file_format, expected_info), expected_info; encoded)
            @test s == s1 == s2
            @test s.info == expected_info
            @test TimeSpans.istimespan(s)
            @test TimeSpans.duration(s) == TimeSpans.time_from_index(s.info.sample_rate, size(s.data, 2) + 1)
            @test channel_count(s) == channel_count(s.info) == length(s.info.channels)
            @test sample_count(s) == sample_count(s.info, TimeSpans.duration(s)) == size(s.data, 2)
            encoded || continue # everything after this assumes `encoded` is `true`
            if signal.file_format == "lpcm"
                s1_mmap = Onda.mmap(signal)
                s2_mmap = Onda.mmap(signal.file_path, s.info)
                s3_mmap = open(io -> Onda.mmap(io, s.info), signal.file_path)
                @test s == s1_mmap == s2_mmap == s3_mmap
            else
                @test_throws ArgumentError Onda.mmap(signal)
            end
            @test sizeof(Matrix(s.data)) == sizeof_samples(s.info, TimeSpans.duration(s))
            @test encode(s) === s
            tmp = similar(s.data)
            tmp_dither_storage = zeros(size(s.data))
            encode!(tmp, s.info.sample_resolution_in_unit,
                    s.info.sample_offset_in_unit, decode(s).data,
                    tmp_dither_storage)
            @test tmp == encode(sample_type(s.info), s.info.sample_resolution_in_unit,
                                s.info.sample_offset_in_unit, decode(s).data + tmp_dither_storage,
                                nothing)
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
            decode!(tmp, s.info.sample_resolution_in_unit, s.info.sample_offset_in_unit, s.data)
            @test tmp == d.data
            @test d.data == (s.data .* s.info.sample_resolution_in_unit .+ s.info.sample_offset_in_unit)
            if sizeof(sample_type(s.info)) >= 8
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
            chs = s.info.channels
            i = 27
            @test s[:, i].data == s.data[:, i:i]
            t = TimeSpans.time_from_index(s.info.sample_rate, i)
            t2 = TimeSpans.time_from_index(s.info.sample_rate, i + 15)
            j = TimeSpans.index_from_time(s.info.sample_rate, t2) - 1
            for (ch_inds, reg) in ((:, r""), (1:2, r"[ab]"), (2:3, r"[bc]"), (1:3, r"[abc]"), ([3,1], :skip), ([2,3,1], :skip), ([1,2,3], r"[abc]"))
                @test s[chs[ch_inds], t].data == s[ch_inds, i].data
                @test s[chs[ch_inds], TimeSpan(t, t2)].data == s.data[ch_inds, i:j]
                @test s[chs[ch_inds], i:j].data == s.data[ch_inds, i:j]
                @test s[ch_inds, t].data == s[ch_inds, i].data
                @test s[ch_inds, TimeSpan(t, t2)].data == s.data[ch_inds, i:j]
                @test s[ch_inds, i:j].data == s.data[ch_inds, i:j]
                reg === :skip && continue # can't represent the index with regex
                @test s[reg, t].data == s[ch_inds, i].data
                @test s[reg, TimeSpan(t, t2)].data == s.data[ch_inds, i:j]
                @test s[reg, i:j].data == s.data[ch_inds, i:j]
            end
            @test size(s[:, TimeSpan(0, Second(1))].data, 2) == floor(s.info.sample_rate)
            for i in 1:length(chs)
                @test channel(s, chs[i]) == i
                @test channel(s, i) == chs[i]
                @test channel(s.info, chs[i]) == i
                @test channel(s.info, i) == chs[i]
            end
            @test s[:, TimeSpan(0, TimeSpans.duration(s))].data == s.data
        end
    end
end

@testset "`Samples` pretty printing" begin
    info = SamplesInfo(kind="eeg",
                       channels=["a", "b", "c-d"],
                       sample_unit="unit",
                       sample_resolution_in_unit=0.25,
                       sample_offset_in_unit=-0.5,
                       sample_type=Int16,
                       sample_rate=50.2)
    samples = Samples(rand(Random.MersenneTwister(0), sample_type(info), 3, 5), info, true)
    M = VERSION >= v"1.6" ? "Matrix{Int16}" : "Array{Int16,2}"
    @test sprint(show, samples, context=(:compact => true)) == "Samples(3×5 $M)"
    @test sprint(show, samples) == """
                                   Samples (00:00:00.099601594):
                                     info.kind: "eeg"
                                     info.channels: ["a", "b", "c-d"]
                                     info.sample_unit: "unit"
                                     info.sample_resolution_in_unit: 0.25
                                     info.sample_offset_in_unit: -0.5
                                     sample_type(info): Int16
                                     info.sample_rate: 50.2 Hz
                                     encoded: true
                                     data:
                                   3×5 $M:
                                    20032  4760  27427  -20758   24287
                                    14240  5037   5598   -5888   21784
                                    16885   600  20880  -32493  -19305"""
end

@testset "Onda.validate_samples_on_construction" begin
    info = SamplesInfo(kind="kind",
                       channels=["a", "b", "c"],
                       sample_unit="microvolt",
                       sample_resolution_in_unit=1.0,
                       sample_offset_in_unit=0.0,
                       sample_type=Int16,
                       sample_rate=100.0)
    @test Onda.validate_samples_on_construction()
    @test_throws ArgumentError Samples(rand(4, 10), info, false)
    @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
    Onda.validate_samples_on_construction() = false
    @test Samples(rand(4, 10), info, false) isa Samples
    @test Samples(rand(Int32, 3, 10), info, true) isa Samples
    @test_throws ArgumentError Onda.validate(Samples(rand(4, 10), info, false))
    @test_throws ArgumentError Onda.validate(Samples(rand(Int32, 3, 10), info, true))
    Onda.validate_samples_on_construction() = true
    @test_throws ArgumentError Samples(rand(4, 10), info, false)
    @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
end