function minio_server(body, dirs=[mktempdir()]; address="localhost:9005")
    server = Minio.Server(dirs; address)

    try
        run(server; wait=false)
        sleep(0.5)  # give the server just a bit of time, though it is amazingly fast to start

        config = MinioConfig(
            "http://$address"; username="minioadmin", password="minioadmin"
        )
        body(config)
    finally
        # Make sure we kill the server even if a test failed.
        kill(server)
    end
end

@testset "AWSS3 usage" begin
    minio_server() do config
        s3_create_bucket(config, "test-bucket")

        file_format = "lpcm.zst"
        file_path = S3Path("s3://test-bucket/prefix/samples.$(file_format)"; config)
        recording_uuid = uuid4()
        start = Second(0)

        info = SamplesInfoV2(sensor_type="eeg",
            channels=["a", "b"],
            sample_unit="unit",
            sample_resolution_in_unit=1.0,
            sample_offset_in_unit=0.0,
            sample_type=Int16,
            sample_rate=100.0)
        samples = Samples(rand(sample_type(info), 2, 300), info, true)

        signal = Onda.store(file_path, file_format, samples, recording_uuid, start)
        @test signal.file_path isa S3Path

        loaded_samples = Onda.load(signal; encoded=true)
        @test samples == loaded_samples

        # Load subspan to exercise method
        span = TimeSpan(0, Second(1))
        loaded_span = Onda.load(signal, span; encoded=true)
        @test loaded_samples[:, span] == loaded_span
    end
end
