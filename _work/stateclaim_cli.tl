--- Native claim publication uses the same immutable transition as item edits.
local boardread = require("_work.boardread")
local claim = require("_work.claim")
local gate = require("_work.gitgate")
local item = require("_work.item")
local publish = require("_work.publish")
local refs = require("_work.refs")
local stateclaim = require("_work.stateclaim")
local statewrite = require("_work.statewrite")
local staging = require("_work.statestaging")
local store = require("_work.store")
--- `claim`, `renew` and `drop` on a native board: one commit writing every
--- member's `claims/<id>`, refused whole when any member is refused, carrying
--- the earliest member's expiry as the deadline the final push is checked
--- against. Claim operations are refused inside a draft overlay — a lease
--- nobody else can see is not a lease.
--- @param s store.Store The open store
--- @param ids {string} The members
--- @param all {item.Item} The board, for resolving each member
--- @param action stateclaim.Action take, renew or drop
--- @param caller string The session asking
--- @param remote string The remote the caller expects to publish to
--- @param force boolean Whether to supersede another session's live lease
--- @param why string The reason a forced acquisition carries
--- @param execute boolean Whether to push now
--- @param base function The product base to record for a member
--- @return integer The verdict line's exit status
local function run(s: store.Store, ids: {string}, all: {item.Item},
    action: stateclaim.Action, caller: string, remote: string, force: boolean, why: string,
    execute: boolean, base: function(item.Item): string | nil, string): integer
  if remote ~= refs.board_remote(s.root) then
    return gate.verdict_line("claim", false, "native claim destination differs from configured board remote")
  end
  if staging.active(s.root) ~= nil then
    return gate.verdict_line("claim", false, "claim operations cannot run inside a draft overlay")
  end
  local by_id = item.by_id(all)
  local now = os.time()
  local view, view_err = boardread.list(s.root, s.state_head)
  if view == nil then return gate.verdict_line("claim", false, view_err) end
  local requests: {stateclaim.Request} = {}
  local early: {string: string} = {}
  for _, id in ipairs(ids) do
    local it = by_id[id]
    local product = ""
    if it == nil then early[id] = "no such item"
    elseif action == "take" and not (view.claims_by_id[id] ~= nil
      and view.claims_by_id[id].holder == caller
      and claim.status(stateclaim.state(view.claims_by_id[id]), now) == "active") then
      local value, err = base(it)
      if value == nil then early[id] = err else product = value end
    end
    requests[#requests + 1] = {id = id, product_base = product}
  end
  local verb = action == "take" and "claim" or action
  local result = stateclaim.prepare(s.root, s.state_head, requests, action, caller,
    now, force, why)
  for id, err in pairs(early) do result.refused[id] = err end
  if next(result.refused) ~= nil then
    local ordered: {string} = {}; for id in pairs(result.refused) do ordered[#ordered + 1] = id end; table.sort(ordered)
    for _, id in ipairs(ordered) do print("refused " .. id .. ": " .. result.refused[id]) end
    return gate.verdict_line(verb, false, "batch rejected; no item succeeded")
  end
  if #result.changes == 0 then
    for _, member in ipairs(result.members) do
      print(("held %s claim=%s branch=%s expires=%d"):format(
          member.id, member.claim_root, member.branch, member.expires_at))
    end
    return gate.verdict_line(verb, true, "active claims held; leases unchanged")
  end
  for _, dependency in ipairs(result.dependencies) do
    s.state_paths[dependency.path], s.state_reads[dependency.path] = dependency.id, dependency.id
  end
  local message = stateclaim.message(action, caller, why)
  if force then message = message .. "\n\nForce-Why: " .. why end
  s.session, s.op = caller, verb
  -- Direct claim establishes exclusion only. Pull readiness belongs to the
  -- `take` path; a claim may deliberately reserve unranked or unspecced work
  -- while its caller rechecks the measured facts before building.
  local ok, err = statewrite.transition(s, result.changes, message,
    result.publish_by)
  if not ok then return gate.verdict_line(verb, false, err) end
  local landed, lerr = publish.publish(s, execute)
  if not landed then return gate.verdict_line(verb, false, lerr) end
  if lerr ~= nil and lerr ~= "" then print(lerr) end
  local confirmed = refs.board_mode(s.root) == "local" or execute
  if confirmed then
    local current, current_err = boardread.list(s.root, s.state_head)
    if current == nil then return gate.verdict_line(verb, false, current_err) end
    for _, member in ipairs(result.members) do
      local actual = current.claims_by_id[member.id]
      if action == "drop" then
        if actual ~= nil then confirmed = false end
      elseif actual == nil or actual.id ~= member.claim_root or actual.holder ~= caller
      or actual.expires_at ~= member.expires_at
      or claim.status(stateclaim.state(actual), os.time()) ~= "active" then
        confirmed = false
      end
    end
  end
  for _, member in ipairs(result.members) do
    print(("%s %s operation=%s claim=%s branch=%s expires=%d"):format(
        confirmed and "confirmed" or "prepared", member.id, member.operation,
        member.claim_root, member.branch, member.expires_at))
  end
  gate.verdict_line(verb, true, confirmed and "claim set confirmed" or
    "PREPARED; no claim authority until refresh confirms the current claim state")
  return confirmed and 0 or 2
end
local record Module
  run: function(store.Store, {string}, {item.Item}, stateclaim.Action, string, string, boolean, string,
  boolean, function(item.Item): string | nil, string): integer
end
local M: Module = {run = run}
return M
