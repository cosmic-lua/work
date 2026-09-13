--- Publication proof checks every first-parent transition, never only the tip tree.
local tx = require("_work.statetransaction")
local projection = require("_work.stateplan_git")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local SEARCH_LIMIT < const > = 1024
local record Status
  status: string
  candidate: string
  reason: string
  absence_proven: boolean
end
--- Whether two transitions are the same publication: the changed paths and
--- their content, the message, and the logical author — all three, because a
--- commit with a matching `Transaction:` trailer but different content is not
--- this attempt, and neither is one that landed under another author.
--- @param a tx.Transition One transition
--- @param b tx.Transition The other
--- @return boolean True when they are the same publication
local function same_transition(a: tx.Transition, b: tx.Transition): boolean
  return literal.encode(a.changes) == literal.encode(b.changes)
  and a.message == b.message and literal.encode(a.author) == literal.encode(b.author)
end
--- Whether `tip`'s first-parent chain carries the frozen chain WHOLE: one
--- commit per transition, walked back in order, each compared by content. A
--- candidate that reaches the same final tree with a transition missing or
--- squashed fails here, which is the point — the branch's history is the log.
--- @param root string The repository holding `tip`
--- @param tip string The candidate tip
--- @param frozen tx.Frozen The attempt to confirm against
--- @return boolean True when every transition is present, in order
--- @return string Which transition differs, or why the walk could not continue
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
--- @param candidate A recorded returned SHA, which may be old or on a side branch.
--- @return Whether it occurs on head's first-parent chain, without a generation cap.
local function recorded_on_chain(root: string, head: string, candidate: string): boolean, string
  if head == candidate then return true, "" end
  local exists = git.probe(root, {"cat-file", "-e", candidate .. "^{commit}"})
  if not exists then return false, "" end
  local path, err = git.text(root, {"rev-list", "--first-parent", head, "^" .. candidate, "--"})
  if path == nil then return false, err end
  local oldest = path:match("([0-9a-f]+)$")
  if oldest == nil then return false, "" end
  local parents, perr = git.text(root, {"show", "-s", "--format=%P", oldest})
  if parents == nil then return false, perr end
  return parents:match("^([0-9a-f]+)") == candidate, ""
end
--- @param head One fetched canonical head; history before the staged base is excluded.
--- @param published_sha Optional connector-returned candidate, never proof by itself.
--- @return Confirmed only after complete equality; truncated searches stay pending.
local function inspect(root: string, head: string, frozen: tx.Frozen,
    published_sha?: string, current_staging_sha?: string): Status | nil, string
  local normalized, err = tx.freeze(frozen)
  if normalized == nil then return nil, err end
  if current_staging_sha ~= nil and current_staging_sha ~= frozen.staging_sha then
    return {status = "pending", candidate = "", reason = "draft advanced after publication snapshot", absence_proven = false}, ""
  end
  if published_sha ~= nil and published_sha ~= "" then
    local known, kerr = recorded_on_chain(root, head, published_sha)
    if kerr ~= "" then return nil, kerr end
    if known then
      local complete, cerr = complete_chain(root, published_sha, normalized)
      if complete then return {status = "confirmed", candidate = published_sha, reason = "", absence_proven = false}, "" end
      return {status = "conflict", candidate = published_sha, reason = cerr, absence_proven = false}, ""
    end
  end
  -- Git parses the trailer block once per commit inside one subprocess. The
  -- separator and comment grammar are explicit, independent of local config.
  local history, herr = git.run(root, {"-c", "trailer.separators=:", "-c", "core.commentChar=#",
      "-c", "trailer.Transaction.key=Transaction",
      "log", "--first-parent", "--max-count=" .. tostring(SEARCH_LIMIT + 1),
      "--format=%H%x00%(trailers:key=Transaction,valueonly,unfold,separator=%x1f)%x00",
      head, "^" .. normalized.transitions[1].base, "--"})
  if history == nil then return nil, herr end
  local conflict = ""
  local scanned = 0
  for sha, parsed in history:gmatch("([0-9a-f]+)%z([^%z]*)%z") do
    scanned = scanned + 1
    if scanned > SEARCH_LIMIT then
      return {status = "pending", candidate = "", reason = "receipt search limit reached; no attempt retired", absence_proven = false}, ""
    end
    local located = published_sha ~= nil and sha == published_sha
    if not located then
      local identifier = parsed:gsub("%s+$", "")
      located = identifier == normalized.transaction
    end
    if located then
      local complete, cerr = complete_chain(root, sha, normalized)
      if complete then return {status = "confirmed", candidate = sha, reason = "", absence_proven = false}, "" end
      conflict = cerr
    end
  end
  local base_reached, berr = recorded_on_chain(root, head, normalized.transitions[1].base)
  if berr ~= "" then return nil, berr end
  if not base_reached and conflict == "" then
    return {status = "pending", candidate = "", reason = "staged base not reached on fetched first-parent history", absence_proven = false}, ""
  end
  return {status = conflict ~= "" and "conflict" or "pending", candidate = "", reason = conflict, absence_proven = conflict == "" and base_reached}, ""
end
local record Module
  type Status = Status
  SEARCH_LIMIT: integer
  complete_chain: function(string, string, tx.Frozen): boolean, string
  inspect: function(root: string, head: string, frozen: tx.Frozen,
  published_sha?: string, current_staging_sha?: string): Status | nil, string
end
local M: Module = {SEARCH_LIMIT = SEARCH_LIMIT, complete_chain = complete_chain, inspect = inspect}
return M
