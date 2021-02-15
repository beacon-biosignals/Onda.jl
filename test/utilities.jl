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
     g = Onda.gather(:x, a, b, c; extract=(t, i) -> t[i])
     dfg = Onda.gather(:x, DataFrame(a), DataFrame(b), DataFrame(c))
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
end