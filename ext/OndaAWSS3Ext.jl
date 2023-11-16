module OndaAWSS3Ext

using AWSS3: S3Path
using Onda: Onda

"""
    Onda.read_byte_range(path::S3Path, byte_offset, byte_count)

Implement method needed for Onda to read a byte range from an S3 path.  Uses
`AWSS3.s3_get` under the hood.

"""
function Onda.read_byte_range(path::S3Path, byte_offset, byte_count)
    # s3_get byte_range is 1-indexed, so we need to add one
    byte_range = range(byte_offset + 1; length=byte_count)
    return read(path; byte_range)
end

# avoid method ambiguity
function Onda.read_byte_range(path::S3Path, ::Missing, ::Missing)
    return read(path)
end

end # module
