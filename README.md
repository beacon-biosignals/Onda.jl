# Onda.jl

[![CI](https://github.com/beacon-biosignals/Onda.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/beacon-biosignals/Onda.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/beacon-biosignals/Onda.jl/branch/master/graph/badge.svg?token=D0bcI0Rtsw)](https://codecov.io/gh/beacon-biosignals/Onda.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://beacon-biosignals.github.io/Onda.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://beacon-biosignals.github.io/Onda.jl/dev)

[Take The Tour](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples/tour.jl)

[See Other Examples](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples)

Onda.jl is a Julia package for high-throughput manipulation of structured LPCM signal data across arbitrary domain-specific encodings, file formats and storage layers via [the Onda Format](https://github.com/beacon-biosignals/OndaFormat).

This package follows the [YASGuide](https://github.com/jrevels/YASGuide).

## Installation

To install Onda for development, run:

```
julia -e 'using Pkg; Pkg.develop(PackageSpec(url="https://github.com/beacon-biosignals/Onda.jl"))'
```

This will install Onda to the default package development directory, `~/.julia/dev/Onda`.
