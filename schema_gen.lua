#!/usr/bin/env tarantool

local json = require('json')
local cluster_config = require('internal.config.cluster_config')
local descriptions = require('descriptions')

-- {{{ descriptions

-- Set the descriptions for the given schema object based on the field
-- path accumulated in ctx.path.
local function set_description(schema_obj, ctx)
    local i = 1
    local field_path = table.concat(ctx.path, '.')

    while field_path ~= "" do
        if descriptions[field_path] ~= nil then
            schema_obj.description = descriptions[field_path]
            return
        else
            field_path = table.concat(ctx.path, '.', i)
            i = i + 1
        end
    end
    field_path = table.concat(ctx.path, '.')
    if field_path ~= "" then
        assert(false, table.concat(ctx.path, '.'))
    end
end

-- This function recursively traverses the schema and adds
-- descriptions based on the fpath accumulated in ctx.path.
local function add_descriptions_impl(schema, ctx)
    set_description(schema, ctx)
    -- if schema is scalar do nothing
    if schema.type == 'record' then
        for field_name, field_def in pairs(schema.fields) do
            table.insert(ctx.path, field_name)
            add_descriptions_impl(field_def, ctx)
            table.remove(ctx.path)
        end
    elseif schema.type == 'map' then
        table.insert(ctx.path, '*')
        add_descriptions_impl(schema.value, ctx)
        table.remove(ctx.path)
    elseif schema.type == 'array' then
        table.insert(ctx.path, '*')
        add_descriptions_impl(schema.items, ctx)
        table.remove(ctx.path)
    end
    return schema
end

local function add_descriptions(schema)
    local ctx = {path = {}}
    return add_descriptions_impl(schema, ctx)
end

-- }}} descriptions

-- {{{ <schema object>:jsonschema()

local function extract_validate_no_repeat()
    local schema

    for _, p in ipairs{'experimental.config.utils.schema', 'internal.config.utils.schema'} do
        local ok, mod = pcall(require, p)
        if ok then
            schema = mod
            break
        end
    end

    local nups = debug.getinfo(schema.set).nups
    for i = 1, nups do
        local k, v = debug.getupvalue(schema.set, i)
        if k == 'validate_no_repeat' then
            return v
        end
    end
end

local validate_no_repeat = extract_validate_no_repeat()
assert(type(validate_no_repeat) == 'function')

local json_scalars = {
    string = {jsonschema = {type = 'string'}},
    number = {jsonschema = {type = 'number'}},
    ['string, number'] = {jsonschema = {type = {'string', 'number'}}},
    ['number, string'] = {jsonschema = {type = {'string', 'number'}}},
    integer = {jsonschema = {type = 'integer'}},
    boolean = {jsonschema = {type = 'boolean'}},
    any = {jsonschema = {}}
}

local function is_scalar(schema_obj)
    return json_scalars[schema_obj.type] ~= nil
end

-- This function sets common fields such as `description`, `default`, and `enum`
-- for a given schema object. These fields are typical in JSON schemas.
local function set_common_fields(res, schema)
    res.description = schema.description
    res.default = schema.default
    res.enum = schema.allowed_values
    return setmetatable(res, {
        __serialize = 'map',
    })
end

local function traverse_impl(schema)
    local schema_type = schema.type

    if is_scalar(schema) then
        -- If the schema is a scalar type (string, number, etc.)
        -- copy the corresponding JSON schema.
        local scalar_copy = table.copy(json_scalars[schema_type].jsonschema)
        return set_common_fields(scalar_copy, schema)

    elseif schema_type == 'record' then
        local properties = {}
        for field_name, field_def in pairs(schema.fields) do
            properties[field_name] = traverse_impl(field_def)
        end
        return set_common_fields({
            type = 'object',
            properties = properties,
            additionalProperties = false
        }, schema)

    elseif schema_type == 'map' then
        assert(schema.key.type == 'string')
        return set_common_fields({
            type = 'object',
            additionalProperties = traverse_impl(schema.value)
        }, schema)

    elseif schema_type == 'array' then
        local res = {
            type = 'array',
            items = traverse_impl(schema.items),
        }
        if schema.validate == validate_no_repeat then
            res.uniqueItems = true
        end
        return set_common_fields(res, schema)

    else
        error('Unsupported schema type: ' .. tostring(schema_type))
    end
end

-- Convert a schema to JSON schema format.
--
-- This method generates a Lua table that represents the current schema
-- in the JSON Schema format. It recursively processes the schema
-- structure and transforms it into a format compliant with the
-- JSON Schema specification.
local function jsonschema(schema)
    local jsonschema = traverse_impl(schema)
    jsonschema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'

    return jsonschema
end

-- }}} <schema object>:jsonschema()

local schema = rawget(cluster_config, 'schema')
schema = add_descriptions(schema)

local version = ...
local text = json.encode(jsonschema(schema))

local filename = string.format("schemas/config.schema.%s.json", version)
local file = io.open(filename, "w")
if file then
    file:write(text)
    file:close()
    print(filename)
end
