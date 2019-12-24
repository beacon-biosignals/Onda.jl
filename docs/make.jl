using Onda
using Documenter

makedocs(modules=[Onda],
         sitename="Onda",
         authors="Jarrett Revels and other contributors",
         pages=["API Documentation" => "index.md"])

# this is commented out until Onda has been open-sourced
# deploydocs(repo="github.com/beacon-biosignals/Onda.jl.git")
