#!/usr/bin/env cosmic
local claim = require("_work.claim")
local receipt = require("_work.preparation_receipt")
local function example(): {string: string}
  local id, root = "3J6sZjQEXeXdymAVueHF456JPKE", ("a"):rep(40)
  return {format = "gitboard-builder-preparation-v1", ["board-root"] = "/board",
    ["board-mode"] = "local", ["board-remote"] = "", item = id, session = ("1"):rep(32),
    ["claim-fact"] = root, ["claim-control"] = root, ["product-base"] = ("b"):rep(40),
    ["product-root"] = "/product", branch = claim.branch(id, root), worktree = "/worktree",
    bootstrap = "cosmic (local build)", ["gitboard-command"] = "", ["gitboard-cwd"] = ""}
end
local function test_round_trip_escaped_bytes_and_shell_looking_data()
  local values = example()
  values["board-root"] = "/space = café\\line\ncr\rtab\t$(never-run)"
  values["gitboard-command"], values["gitboard-cwd"] = "env X='a=b' sh /x\\y; $(not-evaluated)", "/space dir"
  local text, err = receipt.encode(values)
  assert(err == "", err)
  assert(text:find("café\\\\line\\ncr\\rtab\\t", 1, true) ~= nil, text)
  local parsed, derr = receipt.decode(text)
  assert(derr == "", derr)
  for key, value in pairs(values) do assert(parsed[key] == value, key) end
  assert(receipt.encode(parsed) == text)
end
local function test_malformed_wire_is_rejected()
  local text = receipt.encode(example())
  local bad = {
    text:sub(1, -2), text .. "extra=x\n", text:gsub("format=", "unknown=", 1),
    text:gsub("board%-root=/board", "board-root=/bad\\q"),
    text:gsub("board%-root=/board", "board-root=/bad\\"),
    text:gsub("board%-root=/board", "board-root=/bad\0"),
    text:gsub("board%-root=/board", "board-root=/raw\t"),
    text:gsub("preparation%-v1", "preparation-v2"),
    text:gsub("board%-root=/board\n", ""),
    text:gsub("board%-root=/board\n", "board-root=/board\nboard-root=/board\n"),
    (text:gsub("board%-root=/board\nboard%-mode=local\n", "board-mode=local\nboard-root=/board\n")),
  }
  for _, value in ipairs(bad) do
    local parsed, err = receipt.decode(value)
    assert(err ~= "" and next(parsed) == nil, value)
  end
end
local function test_invalid_field_shapes_are_rejected()
  local bad: {string: string} = {format = "other", ["board-mode"] = "invalid",
    ["board-remote"] = "origin", item = "not-id", session = "builder-label",
    ["claim-fact"] = "abc", ["claim-control"] = ("g"):rep(40),
    ["product-base"] = "", branch = "old-branch", ["gitboard-cwd"] = "/only-one",
    ["gitboard-command"] = "line\nbreak"}
  for key, value in pairs(bad) do
    local fields = example()
    fields[key] = value
    local text, err = receipt.encode(fields)
    assert(text == "" and err ~= "", key)
  end
  local fields = example()
  fields.extra = "surprise"
  assert(receipt.encode(fields) == "")
  fields = example()
  fields["board-mode"], fields["board-remote"] = "remote", "origin"
  assert(receipt.encode(fields) ~= "")
end
