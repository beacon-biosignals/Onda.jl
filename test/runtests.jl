using Compat: @compat
using Test, UUIDs, Dates, Onda, Legolas, Arrow, Tables, TimeSpans, DataFrames, Random
using Tables: rowmerge
using AWSS3, Minio # for testing AWSS3 package extension
using AWSS3.AWS: AWSException

function has_rows(a, b)
    for name in propertynames(b)
        getproperty(a, name) == getproperty(b, name) || return false
    end
    for name in Tables.columnnames(b)
        Tables.getcolumn(a, name) == Tables.getcolumn(b, name) || return false
    end
    return true
end

include("annotations.jl")
include("signals.jl")
include("serialization.jl")
include("samples.jl")
include("deprecations.jl")
include("awss3.jl")
include(joinpath(dirname(@__DIR__), "examples", "flac.jl"))
include(joinpath(dirname(@__DIR__), "examples", "tour.jl"))
