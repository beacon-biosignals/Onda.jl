using Onda
using Documenter

makedocs(modules=[Onda],
         sitename="Onda",
         authors="Beacon Biosignals, Inc.",
         pages=["API Documentation" => "index.md"])

deploydocs(repo="github.com/beacon-biosignals/Onda.jl.git")
