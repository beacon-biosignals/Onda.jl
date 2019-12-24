#!/bin/sh

set -e
cd "$(dirname $0)"
julia --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="..")); Pkg.instantiate()'
julia --project=. make.jl
