function table_has_supported_onda_format_version(table)
    m = Arrow.getmetadata(table)
    return m isa Dict && is_supported_onda_format_version(VersionNumber(get(m, "onda_format_version", v"0.0.0")))
end

function read_onda_table(io_or_path; materialize::Bool=false)
    table = Arrow.Table(io_or_path)
    table_has_supported_onda_format_version(table) || error("supported `onda_format_version` not found in annotations file")
    return materialize ? map(collect, Tables.columntable(table)) : table
end

#####
##### `*.signals`
#####

const SIGNAL_COLUMN_NAMES = (:recording_uuid, :file_path, :file_format, :start_nanosecond, :stop_nanosecond, :kind, :channels, :sample_unit, :sample_resolution_in_unit, :sample_offset_in_unit, :sample_type, :sample_rate)
const SIGNAL_COLUMN_SUPERTYPES = Tuple{Union{UUID,UInt128},Any,AbstractString,Nanosecond,Nanosecond,AbstractString,AbstractVector{<:AbstractString},AbstractString,LPCM_SAMPLE_TYPE_UNION,LPCM_SAMPLE_TYPE_UNION,AbstractString,Real}

is_valid_signals_schema(::Any) = false
is_valid_signals_schema(::Tables.Schema{SIGNAL_COLUMN_NAMES,<:SIGNAL_COLUMN_SUPERTYPES}) = true

function validate_signals_schema(schema; error_on_invalid_schema::Bool=true)
    if schema === nothing
        message = "schema is not determinable (schema is `nothing`)"
        if error_on_invalid_schema
            throw(ArgumentError(message))
        else
            @warn message
        end
    elseif !is_valid_signals_schema(schema)
        message = "table does not have appropriate schema for `*.signals`: $schema"
        if error_on_invalid_schema
            throw(ArgumentError(message))
        else
            @warn message
        end
    end
    return nothing
end

function read_signals(io_or_path; materialize::Bool=false, error_on_invalid_schema::Bool=false)
    table = read_onda_table(io_or_path; materialize)
    validate_signals_schema(Tables.schema(table); error_on_invalid_schema)
    return table
end

#####
##### `*.annotations`
#####
