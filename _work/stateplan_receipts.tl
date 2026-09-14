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
  prefix: integer
end
--- Whether two transitions are the same publication: the changed paths and
--- their content, the message, and the logical author — all three, because a
--- commit with a matching `Transaction:` trailer but different content is not
--- this attempt, and neither is one that landed under another author.
--- @param a tx.Transition One transition
--- @param b tx.Transition The other
--- @return boolean True when they are the same publication
local function transition_key(value: tx.Transition): string
  return (literal.encode(value.changes) or "") .. "\0" .. value.message .. "\0"
  .. (literal.encode(value.author) or "")
end
local function same_transition(a: tx.Transition, b: tx.Transition): boolean
  return transition_key(a) == transition_key(b)
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
--- How much of a longer frozen transaction ends exactly at `tip`. Only a
--- proper leading prefix is returned: a whole transaction is confirmation,
--- while zero matching transitions is an unrelated or conflicting commit.
--- @param root string The repository holding `tip`
--- @param tip string The candidate tip
--- @param frozen tx.Frozen The longer attempt to compare
--- @return integer Number of exact leading transitions, zero when none
local function leading_prefix(root: string, tip: string, frozen: tx.Frozen): integer
  local normalized = tx.freeze(frozen)
  if normalized == nil or #normalized.transitions < 2 then return 0 end
  local after_base, aerr = recorded_on_chain(root, tip, normalized.transitions[1].base)
  if not after_base or aerr ~= "" then return 0 end
  local pattern: {string} = {}
  local fallback: {integer} = {}
  for index = 1, #normalized.transitions - 1 do
    pattern[index] = transition_key(normalized.transitions[index])
    local prior = index > 1 and fallback[index - 1] or 0
    while prior > 0 and pattern[prior + 1] ~= pattern[index] do prior = fallback[prior] end
    if index > 1 and pattern[prior + 1] == pattern[index] then prior = prior + 1 end
    fallback[index] = prior
  end
  local reverse: {string} = {}
  local current = tip
  for _ = 1, #pattern do
    if current == normalized.transitions[1].base then break end
    local parents = git.text(root, {"rev-list", "--parents", "-n", "1", current})
    if parents == nil then return 0 end
    local own, parent = parents:match("^([0-9a-f]+) ([0-9a-f]+)$")
    if own == nil then return 0 end
    local observed = projection.capture(root, parent, current, {})
    if observed == nil then return 0 end
    reverse[#reverse + 1] = transition_key(observed)
    current = parent
  end
  local matched = 0
  for index = #reverse, 1, -1 do
    local key = reverse[index]
    while matched > 0 and pattern[matched + 1] ~= key do matched = fallback[matched] end
    if pattern[matched + 1] == key then matched = matched + 1 end
  end
  return matched
end
--- @param head One fetched canonical head; history before the staged base is excluded.
--- @param published_sha Optional connector-returned candidate, never proof by itself.
--- @return Confirmed only after complete equality; truncated searches stay pending.
local function inspect(root: string, head: string, frozen: tx.Frozen,
    published_sha?: string, current_staging_sha?: string): Status | nil, string
  local normalized, err = tx.freeze(frozen)
  if normalized == nil then return nil, err end
  if current_staging_sha ~= nil and current_staging_sha ~= frozen.staging_sha then
    return {status = "pending", candidate = "", reason = "draft advanced after publication snapshot",
      absence_proven = false, prefix = 0}, ""
  end
  if published_sha ~= nil and published_sha ~= "" then
    local known, kerr = recorded_on_chain(root, head, published_sha)
    if kerr ~= "" then return nil, kerr end
    if known then
      local complete, cerr = complete_chain(root, published_sha, normalized)
      if complete then return {status = "confirmed", candidate = published_sha, reason = "",
          absence_proven = false, prefix = 0}, "" end
      return {status = "conflict", candidate = published_sha, reason = cerr,
        absence_proven = false, prefix = 0}, ""
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
      return {status = "pending", candidate = "", reason = "receipt search limit reached; no attempt retired",
        absence_proven = false, prefix = 0}, ""
    end
    local located = published_sha ~= nil and sha == published_sha
    if not located then
      local identifier = parsed:gsub("%s+$", "")
      located = identifier == normalized.transaction
    end
    if located then
      local complete, cerr = complete_chain(root, sha, normalized)
      if complete then return {status = "confirmed", candidate = sha, reason = "",
          absence_proven = false, prefix = 0}, "" end
      local prefix = leading_prefix(root, sha, normalized)
      if prefix > 0 and conflict == "" then
        return {status = "prefix", candidate = sha,
          reason = "publication contains an exact leading prefix of " .. tostring(prefix) .. " transition(s)",
          absence_proven = false, prefix = prefix}, ""
      end
      conflict = cerr
    end
  end
  local base_reached, berr = recorded_on_chain(root, head, normalized.transitions[1].base)
  if berr ~= "" then return nil, berr end
  if not base_reached and conflict == "" then
    return {status = "pending", candidate = "", reason = "staged base not reached on fetched first-parent history",
      absence_proven = false, prefix = 0}, ""
  end
  return {status = conflict ~= "" and "conflict" or "pending", candidate = "", reason = conflict,
    absence_proven = conflict == "" and base_reached, prefix = 0}, ""
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
