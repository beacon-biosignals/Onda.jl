@testset "`Samples` API" begin
    root = mktempdir()
    signals = SignalV2[]
    possible_recordings = (uuid4(), uuid4(), uuid4())
    expected_sample_types = (UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64)
    expected_parameters = [(recording=rand(possible_recordings),
                            file_path=joinpath(root, "x_$(i)_file"),
                            file_format=rand(("lpcm", "lpcm.zst")),
                            sensor_type="x_$i",
                            sensor_label="x_$(i)_label",
                            channels=["a_$i", "b_$i", "c_$i"],
                            sample_unit="unit_$i",
                            sample_resolution_in_unit=rand((0.25, 1)),
                            sample_offset_in_unit=rand((-0.25, 0.25)),
                            sample_type=expected_sample_types[i],
                            sample_rate=rand((128, 50.5)),
                            start=Second(rand(0:30))) for i in 1:length(expected_sample_types)]
    for params in expected_parameters
        info = SamplesInfoV2(params)
        data = rand(params.sample_type, 3, sample_count(info, Second(rand(2:15))))
        samples = Samples(data, info, true)
        signal = store(params.file_path, params.file_format, samples, params.recording, params.start, params.sensor_label)
        push!(signals, signal)
    end
    for (expected, signal) in zip(expected_parameters, signals)
        expected_info = SamplesInfoV2(expected)
        @test_throws ArgumentError load(signal, TimeSpans.translate(TimeSpan(0, duration(signal.span)), Second(1)))
        for encoded in (false, true)
            s = @compat load(signal; encoded)
            s1 = @compat load(expected.file_path, expected.file_format, expected_info; encoded)
            s2 = @compat load(expected.file_path, Onda.format(expected.file_format, expected_info), expected_info; encoded)
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
                df32 = decode(s, Float32).data
                @test df32 == decode(Float32(s.info.sample_resolution_in_unit), Float32(s.info.sample_offset_in_unit), s.data)
                @test eltype(df32) == Float32
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
            @test size(s[:, TimeSpan(0, Second(1))].data, 2) == ceil(s.info.sample_rate)
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

@testset "`Samples` indexing errors" begin
    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c-d"],
                         sample_unit="unit",
                         sample_resolution_in_unit=0.25,
                         sample_offset_in_unit=-0.5,
                         sample_type=Int16,
                         sample_rate=50.2)

    samples = Samples(rand(Random.MersenneTwister(0), sample_type(info), 3, 5), info, true)

    @test_throws ArgumentError("channel \"aa\" not found") samples["aa", :]
end

@testset "`Samples` pretty printing" begin
    info = SamplesInfoV2(sensor_type="eeg",
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
                                     info.sensor_type: "eeg"
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

@testset "Onda.VALIDATE_SAMPLES_DEFAULT" begin
    info = SamplesInfoV2(sensor_type="sensor_type",
                         channels=["a", "b", "c"],
                         sample_unit="microvolt",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
    @test Onda.VALIDATE_SAMPLES_DEFAULT[]
    @test_throws ArgumentError Samples(rand(4, 10), info, false)
    @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
    Onda.VALIDATE_SAMPLES_DEFAULT[] = false
    @test Samples(rand(4, 10), info, false) isa Samples
    @test Samples(rand(Int32, 3, 10), info, true) isa Samples
    @test_throws ArgumentError Onda.validate_samples(rand(4, 10), info, false)
    @test_throws ArgumentError Onda.validate_samples(rand(Int32, 3, 10), info, true)
    Onda.VALIDATE_SAMPLES_DEFAULT[] = true
    @test_throws ArgumentError Samples(rand(4, 10), info, false)
    @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
end

# A custom path type akin to those from FilePathsBase.jl
struct BufferPath
    io::IOBuffer
end
Base.write(p::BufferPath, bytes) = write(p.io, bytes)
Base.read(p::BufferPath) = take!(p.io)

@testset "Custom path support for store/load" begin
    file_path = BufferPath(IOBuffer())
    file_format = "lpcm.zst"
    recording_uuid = uuid4()
    start = Second(0)

    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b"],
                         sample_unit="unit",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
    samples = Samples(zeros(sample_type(info), 2, 3), info, true)

    signals = Onda.store(file_path, file_format, samples, recording_uuid, start)
    @test signals.file_path isa BufferPath

    loaded_samples = Onda.load(file_path, file_format, info; encoded=true)
    @test samples == loaded_samples
end

@testset "Base.convert" begin
    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c"],
                         sample_unit="unit",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
    # We can convert unencoded samples, since there is no constraint between the eltype of the
    # data and the sample type
    samples = Samples(rand(Float32, 3, 100), info, false)

    s2 = convert(Samples{Matrix{Float64}}, samples)
    @test s2.data ≈ samples.data
    @test s2.info == samples.info
    @test eltype(s2.data) == Float64
    @test s2.data isa Matrix{Float64}

    # In particular, this fixes an arrow deserialization issue
    # (https://github.com/beacon-biosignals/Onda.jl/issues/156)
    table = [(; col = samples), (; col = samples)]
    # Here, materializing this table in this way threw an error before `convert` was defined
    rt_table = DataFrame(Arrow.Table(Arrow.tobuffer(table)); copycols=true)
    rt = rt_table[1, "col"]
    @test rt.data isa AbstractMatrix{Float32}
    @test rt == samples

    # For encoded samples, in generally we cannot `convert`.
    # We choose to not update encoding parameter in `convert`, since `convert` can be implied
    # implicitly, and changing the encoding parameters seems like too big of a change.
    # Therefore, validation errors.
    samples = Samples(rand(sample_type(info), 3, 100), info, true)
    @test_throws "encoded `data` matrix eltype does not match `sample_type(info)`" convert(Samples{Matrix{Int32}}, samples)
end

@testset "Base.copy" begin
    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c"],
                         sample_unit="unit",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
    samples = Samples(rand(sample_type(info), 3, 100), info, true)
    copy_samples = copy(samples)
    @test copy_samples == samples
    @test copy_samples.data !== samples.data
    @test copy_samples.info == info
    @test copy_samples.info.channels !== info.channels === samples.info.channels
end

@testset "Base.isequal and Base.hash" begin
    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c"],
                         sample_unit="unit",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Float32,
                         sample_rate=100.0)
    samples = Samples(ones(sample_type(info), 3, 100), info, true)
    samples2 = deepcopy(samples)
    @test samples == samples2
    @test isequal(samples, samples2)

    samples.data[1,1] = samples2.data[1,1] = NaN
    @test samples != samples2
    @test isequal(samples, samples2)
    @test hash(samples) == hash(samples2)
end

@testset "Samples views" begin

    info = SamplesInfoV2(sensor_type="eeg",
                         channels=["a", "b", "c"],
                         sample_unit="unit",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
    samples = Samples(rand(sample_type(info), 3, 100), info, true)

    span = TimeSpan(Millisecond(100), Millisecond(400))

    for chans in ["a", 1, r"[ac]", 1:2, [1,3]]
        for times in [1, 10:40, span]
            @testset "chans $chans, times $times" begin
                @test view(samples, chans, times) == samples[chans, times]

                v = @view samples[chans, times]
                @test v.data isa SubArray
                @test v == samples[chans, times]

                v = @views samples[chans, times]
                @test v.data isa SubArray
                @test v == samples[chans, times]
            end
        end
    end
end
