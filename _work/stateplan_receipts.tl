--- Publication proof checks every first-parent transition, never only the tip tree.
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local record Status
  status: string
  candidate: string
  reason: string
end
local function same_transition(a: tx.Transition, b: tx.Transition): boolean
  return literal.encode(a.changes) == literal.encode(b.changes)
  and a.message == b.message and literal.encode(a.author) == literal.encode(b.author)
end
local function complete_chain(root: string, tip: string, frozen: tx.Frozen): boolean, string
  local normalized, nerr = tx.freeze(frozen)
  if normalized == nil then return false, nerr end
  local current = tip
  for index = #normalized.transitions, 1, -1 do
    local parents, err = git.text(root, {"rev-list", "--parents", "-n", "1", current})
    if parents == nil then return false, err end
    local own, parent = parents:match("^([0-9a-f]+) ([0-9a-f]+)$")
    if own == nil then return false, "publication transition has missing or multiple parents" end
    local observed, cerr = projection.capture(root, parent, current, {})
    if observed == nil then return false, cerr end
    if not same_transition(observed, normalized.transitions[index]) then
      return false, "publication differs from frozen transition " .. tostring(index)
    end
    current = parent
  end
  return true, ""
end
local function has_transaction(root: string, sha: string, id: string): boolean, string
  local raw, err = git.run(root, {"cat-file", "commit", sha})
  if raw == nil then return false, err end
  local message = raw:match("\n\n(.*)$") or ""
  local trailers, terr = git.run(root, {"interpret-trailers", "--parse"}, message)
  if trailers == nil then return false, terr end
  local matches = 0
  for line in trailers:gmatch("([^\n]+)") do
    local value = line:match("^[Tt][Rr][Aa][Nn][Ss][Aa][Cc][Tt][Ii][Oo][Nn]:%s*(.-)%s*$")
    if value == id then matches = matches + 1 end
  end
  return matches == 1, ""
end
local function inspect(root: string, head: string, frozen: tx.Frozen,
    published_sha?: string, current_staging_sha?: string): Status | nil, string
  local ok, err = tx.validate(frozen)
  if not ok then return nil, err end
  if current_staging_sha ~= nil and current_staging_sha ~= frozen.staging_sha then
    return {status = "pending", candidate = "", reason = "draft advanced after publication snapshot"}, ""
  end
  local history, herr = git.text(root, {"rev-list", "--first-parent", head})
  if history == nil then return nil, herr end
  local conflict = ""
  for sha in history:gmatch("([^\n]+)") do
    local located = published_sha ~= nil and sha == published_sha
    if not located then
      local match, merr = has_transaction(root, sha, frozen.transaction)
      if merr ~= "" then return nil, merr end
      located = match
    end
    if located then
      local complete, cerr = complete_chain(root, sha, frozen)
      if complete then return {status = "confirmed", candidate = sha, reason = ""}, "" end
      conflict = cerr
    end
  end
  return {status = conflict ~= "" and "conflict" or "pending", candidate = "", reason = conflict}, ""
end
local record Module
  type Status = Status
  complete_chain: function(string, string, tx.Frozen): boolean, string
  inspect: function(root: string, head: string, frozen: tx.Frozen,
  published_sha?: string, current_staging_sha?: string): Status | nil, string
end
local M: Module = {complete_chain = complete_chain, inspect = inspect}
return M
