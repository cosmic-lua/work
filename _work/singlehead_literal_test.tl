#!/usr/bin/env cosmic
--- The tagged literal codec preserves list semantics without executing input.
local wire = require("_work.singlehead_literal")

local function test_nested_roundtrip_and_empty_sequence_identity()
  local binary = "\0\1\2\255text\0\254"
  local value = {bytes = binary, map = {}, nested = {{name = "one"}},
    empty = wire.sequence()}
  local encoded, err = wire.encode(value)
  assert(encoded ~= nil, err)
  assert(encoded:sub(1, 7) == "return ")
  local decoded, derr = wire.decode_object(encoded)
  assert(decoded ~= nil, derr)
  local nested = decoded.nested
  assert(nested is {any} and decoded.bytes == binary and #nested == 1)
  assert(not wire.is_sequence(decoded.map) and wire.is_sequence(decoded.empty))
  assert(assert(wire.encode(decoded)) == encoded)
end
test_nested_roundtrip_and_empty_sequence_identity()

local function test_sequence_entries_are_positioned_by_keys()
  local source = [[return {value={["$gitboard"]="sequence-v1", count=2,
entries={["000000002"]="two", ["000000001"]="one"}}}
]]
  local decoded, err = wire.decode_object(source)
  assert(decoded ~= nil, err)
  local values = decoded.value
  assert(values is {any} and values[1] == "one" and values[2] == "two")
end
test_sequence_entries_are_positioned_by_keys()

local function test_malformed_sequences_and_mixed_tables_are_refused()
  local malformed = {
    [[return {x={["$gitboard"]="sequence-v1", count=2,
entries={["000000001"]="one"}}}
]],
    [[return {x={["$gitboard"]="sequence-v1", count=1,
entries={["1"]="one"}}}
]],
    [[return {x={["$gitboard"]="sequence-v1", count=0, entries={}, extra=true}}
]],
  }
  for _, source in ipairs(malformed) do
    local decoded = wire.decode(source)
    assert(decoded == nil, source)
  end
  local encoded = wire.encode({list = {[1] = "one", label = "mixed"}})
  assert(encoded == nil)
end
test_malformed_sequences_and_mixed_tables_are_refused()

local function test_input_is_parsed_and_never_executed()
  local decoded, err = wire.decode([[return {x=os.getenv("HOME")}
]])
  assert(decoded == nil and err:find("literals only", 1, true), err)
  decoded, err = wire.decode([[return {x=1, x=2}
]])
  assert(decoded == nil and err:find("repeats the key", 1, true), err)
end
test_input_is_parsed_and_never_executed()
print("singlehead_literal_test: ok")
