# Onda.jl

[![Build Status](https://travis-ci.com/beacon-biosignals/Onda.jl.svg?token=Jbjm3zfgVHsfbKqsz3ki&branch=master)](https://travis-ci.com/beacon-biosignals/Onda.jl)
[![codecov](https://codecov.io/gh/beacon-biosignals/Onda.jl/branch/master/graph/badge.svg?token=D0bcI0Rtsw)](https://codecov.io/gh/beacon-biosignals/Onda.jl)

[Take The Tour](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples/tour.jl)

[See Other Examples](https://github.com/beacon-biosignals/Onda.jl/tree/master/examples)

Onda.jl is a Julia package for reading/writing [Onda](https://github.com/beacon-biosignals/OndaFormat) datasets.

This package follows the [YASGuide](https://github.com/jrevels/YASGuide).

## Installation

To install Onda for development, run:

```
julia -e 'using Pkg; Pkg.develop(PackageSpec(url="https://github.com/beacon-biosignals/Onda.jl"))'
```

This will install Onda to the default package development directory, `~/.julia/dev/Onda`.

## Viewing Documentation

Onda is currently in stealth mode (shhh!) so we're not hosting the documentation publicly yet. To view Onda's documentation, simply build it locally and view the generated HTML in your browser:

```sh
./Onda/docs/build.sh
open Onda/docs/build/index.html # or whatever command you use to open HTML
```
