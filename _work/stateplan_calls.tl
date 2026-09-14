--- Connector call records and byte-bounded tree-call construction.
local literal = require("_work.singlehead_literal")

local TREE_CALL_BYTES < const > = 256 * 1024

local record Guard
  publish_by: integer
  expected_head: string
  rule: string
end

local record Call
  id: string
  tool: string
  arguments: {string: any}
  guard: Guard | nil
end

--- Append the minimal ordered create-tree calls for `entries`. An empty set is
--- still one call: it is the correct complete snapshot after deleting the sole
--- leaf. Later chunks build on the SHA returned by the preceding call.
--- @return The symbolic SHA of the final tree, or a refusal.
local function append_tree_calls(out: {Call}, prefix: string, repository: string,
    base_tree: string, entries: {{string: any}}): string | nil, string
  local group = literal.sequence() as {{string: any}} -- cast: connector sequence
  local size, chunk = 0, 0
  local function flush()
    chunk = chunk + 1
    local id = prefix .. tostring(chunk)
    out[#out + 1] = {id = id, tool = "github_create_tree", guard = nil,
      arguments = {repository_full_name = repository,
        base_tree_sha = base_tree ~= "" and base_tree or nil,
        tree_elements = group}}
    base_tree = "$" .. id .. ".sha"
    group = literal.sequence() as {{string: any}} -- cast: connector sequence
    size = 0
  end
  for _, entry in ipairs(entries) do
    local copied: {string: any} = {path = entry.path, mode = entry.mode,
      type = entry["type"], content = entry.content, sha = entry.sha}
    local encoded, err = literal.encode(copied)
    if encoded == nil then return nil, err end
    if #encoded > TREE_CALL_BYTES then return nil, "one tree entry exceeds connector budget" end
    if #group > 0 and size + #encoded > TREE_CALL_BYTES then flush() end
    group[#group + 1] = copied
    size = size + #encoded
  end
  if #group > 0 or chunk == 0 then flush() end
  return base_tree, ""
end

local record Module
  TREE_CALL_BYTES: integer
  type Guard = Guard
  type Call = Call
  append_tree_calls: function({Call}, string, string, string,
  {{string: any}}): string | nil, string
end

local M: Module = {TREE_CALL_BYTES = TREE_CALL_BYTES,
  append_tree_calls = append_tree_calls}
return M
