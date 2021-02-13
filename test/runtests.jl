using Test, UUIDs, Dates, Onda, Tables, TimeSpans, DataFrames

function has_rows(a, b)
    for name in propertynames(b)
        getproperty(a, name) == getproperty(b, name) || return false
    end
    for name in Tables.columnnames(b)
        Tables.getcolumn(a, name) == Tables.getcolumn(b, name) || return false
    end
    return true
end

include("utilities.jl")
include("annotations.jl")
include("signals.jl")
include(joinpath(dirname(@__DIR__), "examples", "flac.jl"))
include(joinpath(dirname(@__DIR__), "examples", "tour.jl"))
