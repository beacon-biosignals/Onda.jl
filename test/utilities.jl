@testset "Onda.gather" begin
      a = [(x=1, y="a", z="k"),
           (x=2, y="b", z="j"),
           (x=4, y="c", z="i"),
           (x=4, y="d", z="h"),
           (x=2, y="e", z="g"),
           (x=5, y="f", z="f"),
           (x=4, y="g", z="e"),
           (x=3, y="h", z="d"),
           (x=1, y="i", z="c"),
           (x=5, y="j", z="b"),
           (x=4, y="k", z="a")]
      b = [(x=1, m=1),
           (x=2, m=2),
           (x=2, m=5),
           (x=5, m=4),
           (x=4, m=6)]
      c = [(test="a", x=1, z=1.0),
           (test="b", x=2, z=1.0),
           (test="d", x=4, z=1.0),
           (test="e", x=2, z=1.0),
           (test="f", x=5, z=1.0),
           (test="h", x=3, z=1.0),
           (test="i", x=1, z=1.0),
           (test="j", x=5, z=1.0),
           (test="k", x=4, z=1.0)]
      dfa, dfb, dfc = DataFrame(a), DataFrame(b), DataFrame(c)
      g = Onda.gather(:x, a, b, c; extract=(t, i) -> t[i])
      dfg = Onda.gather(:x, dfa, dfb, dfc)
      expected = Dict(1 => ([(x=1, y="a", z="k"), (x=1, y="i", z="c")],
                            [(x=1, m=1)],
                            [(test="a", x=1, z=1.0), (test="i", x=1, z=1.0)]),
                      2 => ([(x=2, y="b", z="j"), (x=2, y="e", z="g")],
                            [(x=2, m=2), (x=2, m=5)],
                            [(test="b", x=2, z=1.0), (test="e", x=2, z=1.0)]),
                      3 => ([(x=3, y="h", z="d")],
                            NamedTuple{(:x, :m),Tuple{Int64,Int64}}[],
                            [(test="h", x=3, z=1.0)]),
                      4 => ([(x=4, y="c", z="i"), (x=4, y="d", z="h"), (x=4, y="g", z="e"), (x=4, y="k", z="a")],
                            [(x=4, m=6)],
                            [(test="d", x=4, z=1.0), (test="k", x=4, z=1.0)]),
                      5 => ([(x=5, y="f", z="f"), (x=5, y="j", z="b")],
                            [(x=5, m=4)],
                            [(test="f", x=5, z=1.0), (test="j", x=5, z=1.0)]))
      @test g == expected
      @test keys(dfg) == keys(expected)
      @test all(all(dfg[k] .== DataFrame.(expected[k])) for k in keys(dfg))

      # test both the fast path + fallback path for Onda._iterator_for_column
      @test Onda._iterator_for_column(dfa, :x) === dfa.x
      @test Onda._iterator_for_column(a, :x) == dfa.x
end

@testset "Onda.validate_on_construction" begin
      info = SamplesInfo(kind="kind",
                         channels=["a", "b", "c"],
                         sample_unit="microvolt",
                         sample_resolution_in_unit=1.0,
                         sample_offset_in_unit=0.0,
                         sample_type=Int16,
                         sample_rate=100.0)
      @test Onda.validate_on_construction()
      @test_throws ArgumentError Samples(rand(4, 10), info, false)
      @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
      @test_throws ArgumentError setproperties(info; sample_unit="Ha Ha")
      @test_throws ArgumentError setproperties(info; kind="Ha, Ha")
      @test_throws ArgumentError setproperties(info; channel_names=["Ha Ha"])

      Onda.validate_on_construction() = false
      @test Samples(rand(4, 10), info, false) isa Samples
      @test Samples(rand(Int32, 3, 10), info, true) isa Samples
      @test_throws ArgumentError Onda.validate(Samples(rand(4, 10), info, false))
      @test_throws ArgumentError Onda.validate(Samples(rand(Int32, 3, 10), info, true))
      @test_throws ArgumentError Onda.validate(setproperties(info; sample_unit="Ha Ha"))
      @test_throws ArgumentError Onda.validate(setproperties(info; kind="Ha, Ha"))
      @test_throws ArgumentError Onda.validate(setproperties(info; channel_names=["Ha Ha"]))

      Onda.validate_on_construction() = true
      @test_throws ArgumentError Samples(rand(4, 10), info, false)
      @test_throws ArgumentError Samples(rand(Int32, 3, 10), info, true)
      @test_throws ArgumentError setproperties(info; sample_unit="Ha Ha")
      @test_throws ArgumentError setproperties(info; kind="Ha, Ha")
      @test_throws ArgumentError setproperties(info; channel_names=["Ha Ha"])
  end