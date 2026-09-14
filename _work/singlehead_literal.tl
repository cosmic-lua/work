--- Deterministic, non-executable literal wire codec. cosmic.literal accepts
--- only string-keyed tables, so sequences use one reserved tagged shape.
local literal = require("cosmic.literal")

local TAG < const > = "sequence-v1"
local RESERVED < const > = "$gitboard"
local type Sequence = {any}
local SEQUENCE_META: metatable < Sequence > = {}

local function sequence(values?: {any}): {any}
  local out: Sequence = setmetatable(values or {}, SEQUENCE_META)
  return out
end

local function is_sequence(value: any): boolean
  if not (value is {any}) then return false end
  return getmetatable(value as Sequence) == SEQUENCE_META -- cast: narrowed sequence table
end

local function key_of(index: integer): string
  return ("%09d"):format(index)
end

local function to_wire(value: any): any | nil, string
  if type(value) ~= "table" then return value, "" end
  local raw = value as {string | integer: any} -- cast: table keys checked below
  local numbers, strings, maximum = 0, 0, 0
  for key in pairs(raw) do
    if key is integer then
      if key < 1 or key > 999999999 then return nil, "sequence index outside wire range" end
      numbers, maximum = numbers + 1, math.max(maximum, key)
    elseif key is string then
      strings = strings + 1
    else
      return nil, "literal table key must be a string or sequence index"
    end
  end
  local tagged = is_sequence(value)
  if numbers > 0 or tagged then
    if strings > 0 or maximum ~= numbers then
      return nil, "literal sequence must have contiguous integer keys"
    end
    local entries: {string: any} = {}
    for index = 1, numbers do
      local nested, err = to_wire(raw[index])
      if err ~= "" then return nil, err end
      entries[key_of(index)] = nested
    end
    return {[RESERVED] = TAG, count = numbers, entries = entries}, ""
  end
  local out: {string: any} = {}
  for key, item in pairs(raw) do
    if not (key is string) then return nil, "literal map key must be a string" end
    if key == RESERVED then return nil, "literal map uses reserved key " .. RESERVED end
    local nested, err = to_wire(item)
    if err ~= "" then return nil, err end
    out[key] = nested
  end
  return out, ""
end

local function encode(value: any): string | nil, string
  local wire, err = to_wire(value)
  if err ~= "" then return nil, err end
  return literal.format(wire, {layout = "compact"})
end

local function exact_sequence_shape(raw: {string: any}): boolean
  local seen = 0
  for key in pairs(raw) do
    if key ~= RESERVED and key ~= "count" and key ~= "entries" then return false end
    seen = seen + 1
  end
  return seen == 3
end

local function from_wire(value: any): any | nil, string
  if type(value) ~= "table" then return value, "" end
  local raw = value as {string: any} -- cast: cosmic.literal admits string keys only
  local tag = raw[RESERVED]
  if tag ~= nil then
    if tag ~= TAG or not exact_sequence_shape(raw) then
      return nil, "invalid literal sequence tag"
    end
    local count, entries = raw.count, raw.entries
    if not (count is integer) or count < 0 or count > 999999999
    or not (entries is {string: any}) then return nil, "invalid literal sequence shape" end
    local present = 0
    for key in pairs(entries) do
      present = present + 1
      local index = tonumber(key, 10)
      if index == nil or key ~= key_of(math.tointeger(index) or -1) then
        return nil, "invalid literal sequence index"
      end
    end
    if present ~= count then return nil, "invalid literal sequence count" end
    local out = sequence()
    for index = 1, count do
      local item = entries[key_of(index)]
      if item == nil then return nil, "literal sequence has a missing entry" end
      local decoded, err = from_wire(item)
      if err ~= "" then return nil, err end
      out[index] = decoded
    end
    return out, ""
  end
  local out: {string: any} = {}
  for key, item in pairs(raw) do
    local decoded, err = from_wire(item)
    if err ~= "" then return nil, err end
    out[key] = decoded
  end
  return out, ""
end

local function decode(source: string): any | nil, string
  local wire, err = literal.parse(source, {noun = "single-head literal"})
  if wire == nil then return nil, err end
  return from_wire(wire)
end

local function decode_object(source: string): {string: any} | nil, string
  local value, err = decode(source)
  if value == nil then return nil, err end
  if not (value is {string: any}) or is_sequence(value) then
    return nil, "single-head literal must hold an object"
  end
  return value, ""
end

local record SingleHeadLiteral
  encode: function(value: any): string | nil, string
  decode: function(source: string): any | nil, string
  decode_object: function(source: string): {string: any} | nil, string
  sequence: function(values?: {any}): {any}
  is_sequence: function(value: any): boolean
end

local M: SingleHeadLiteral = {encode = encode, decode = decode,
  decode_object = decode_object, sequence = sequence, is_sequence = is_sequence}
return M
