#!/usr/bin/env cosmic
--- Tree chunks remain ordered and every later chunk builds on the returned SHA.
local calls = require("_work.stateplan_calls")
local literal = require("_work.singlehead_literal")

local function entry(path: string, bytes: integer): {string: any}
  return {path = path, mode = "100644", type = "blob", content = string.rep("x", bytes)}
end

local function test_tree_chunking_is_shared_ordered_and_immutable()
  local out: {calls.Call} = {}
  local entries = literal.sequence({entry("a", 140 * 1024), entry("b", 140 * 1024)}) as {{string: any}} -- cast: explicit test connector sequence
  local tip = assert(calls.append_tree_calls(out, "tree_1_", "example/board",
      string.rep("1", 40), entries))
  assert(#out == 2 and out[1].id == "tree_1_1" and out[2].id == "tree_1_2")
  assert(out[2].arguments.base_tree_sha == "$tree_1_1.sha" and tip == "$tree_1_2.sha")
  assert((out[1].arguments.tree_elements as {{string: any}})[1].path == "a") -- cast: generated call shape
  assert((out[2].arguments.tree_elements as {{string: any}})[1].path == "b") -- cast: generated call shape
  entries[1].path = "changed-after-render"
  assert((out[1].arguments.tree_elements as {{string: any}})[1].path == "a") -- cast: generated call shape
end

local function test_empty_complete_tree_and_oversize_entry_have_explicit_results()
  local empty: {calls.Call} = {}
  local tip = assert(calls.append_tree_calls(empty, "tree_1_", "example/board", "",
      literal.sequence() as {{string: any}})) -- cast: explicit empty connector sequence
  assert(#empty == 1 and empty[1].arguments.base_tree_sha == nil
    and #(empty[1].arguments.tree_elements as {{string: any}}) == 0 -- cast: generated call shape
    and tip == "$tree_1_1.sha")
  local rejected, err = calls.append_tree_calls({}, "tree_1_", "example/board", "",
    literal.sequence({entry("too-large", calls.TREE_CALL_BYTES + 1)}) as {{string: any}}) -- cast: explicit test connector sequence
  assert(rejected == nil and err:find("exceeds", 1, true), err)
end
