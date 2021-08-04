using Onda
using Documenter

makedocs(modules=[Onda],
         sitename="Onda",
         authors="Beacon Biosignals, Inc.",
         pages=["API Documentation" => "index.md",
                "Upgrading From Older Versions Of Onda" => "upgrading.md"])

deploydocs(repo="github.com/beacon-biosignals/Onda.jl.git", push_preview=true)
