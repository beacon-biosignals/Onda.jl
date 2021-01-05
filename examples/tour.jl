# This file provides an introductory tour of Onda.jl by generating, storing,
# and loading a toy Onda dataset. Run lines in the REPL to inspect output at
# each step! Tests are littered throughout to demonstrate functionality in a
# concrete manner, and so that we can ensure examples stay updated as the
# package evolves.

# NOTE: It's helpful to read https://github.com/beacon-biosignals/OndaFormat
# before and/or alongside the completion of this tour.

using Onda, TimeSpans, DataFrames, Dates, Test, ConstructionBase

