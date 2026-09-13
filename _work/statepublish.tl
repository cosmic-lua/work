--- Native state publication: immutable plans, bounded retries and content proof.
local stateclaim = require("_work.stateclaim")
local stategate = require("_work.stategate")
local refs = require("_work.refs")
local prepared = require("_work.prepared")
local staging = require("_work.statestaging")
local plan = require("_work.stateplan")
local proof = require("_work.stateplan_receipts")
local store = require("_work.store")
local function head(root: string, remote: string): string | nil, string
  local ref = refs.board_mode(root) == "local" and "refs/heads/state" or "refs/remotes/" .. remote .. "/state"
  return refs.read_ref(root, ref)
end
local function fetch_argv(remote: string): {string}
  return {"git", "fetch", "--atomic", remote,
    "+refs/heads/state:refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end
local function binding(root: string, receipt: staging.Receipt, remote?: string): boolean, string
  if remote ~= nil and remote ~= receipt.remote then return false, "prepared transaction destination differs" end
  if staging.repository(root, receipt.remote) ~= receipt.repository then return false, "prepared repository destination differs" end
  if staging.target_url(root, receipt.remote) ~= receipt.target_url then return false, "prepared remote URL differs" end
  return true, ""
end
local function inspect_current(root: string, receipt: staging.Receipt, known?: string): proof.Status | nil, string
  local current, err = head(root, receipt.remote)
  if current == nil then return nil, err end
  local frozen, ferr = staging.frozen(receipt)
  if frozen == nil then return nil, ferr end
  return proof.inspect(root, current, frozen, known or (receipt.published ~= "" and receipt.published or nil))
end
local function lost(root: string, receipt: staging.Receipt): string
  local retired, err = staging.retire(root, receipt)
  if not retired then return "lost race, but receipt was retained: " .. err end
  return store.LOST_RACE
end
local function build(root: string, receipt: staging.Receipt, remote?: string): plan.Plan | nil, string
  local valid, verr = binding(root, receipt, remote)
  if not valid then return nil, verr end
  local current, err = head(root, receipt.remote)
  if current == nil or current == refs.ZERO_SHA then return nil, err ~= "" and err or "state head is missing" end
  local frozen, ferr = staging.frozen(receipt)
  if frozen == nil then return nil, ferr end
  if current ~= frozen.transitions[1].base then
    local observed, oerr = proof.inspect(root, current, frozen, receipt.published ~= "" and receipt.published or nil)
    if observed == nil then return nil, oerr end
    if observed.status == "confirmed" then return nil, "attempt is already published; refresh to confirm it" end
    if not observed.absence_proven then
      return nil, "publication is not determined: " .. observed.reason
    end
  end
  local projected, perr = plan.build(root, frozen, current, stategate.check)
  if projected == nil and perr:match("^LOST_RACE") then return nil, lost(root, receipt) end
  return projected, perr
end
local function push_argv(receipt: staging.Receipt, candidate: string): {string}
  return {"git", "push", receipt.remote, candidate .. ":refs/heads/state"}
end
local function execute(root: string, receipt: staging.Receipt): boolean, string
  local last_candidate: string = nil
  for attempt = 1, 5 do
    local valid, verr = binding(root, receipt)
    if not valid then return false, verr end
    local observed, oerr = inspect_current(root, receipt, last_candidate)
    if observed == nil then return false, oerr end
    if observed.status == "confirmed" then
      receipt.published = observed.candidate
      local saved, serr = staging.write(root, receipt, receipt.sha)
      if saved == nil then return false, "publication proved, but receipt could not be updated: " .. serr end
      return true, "published " .. observed.candidate .. "; confirmation pending"
    end
    if not observed.absence_proven then return false, "publication is not determined: " .. observed.reason end
    local projected, err = build(root, receipt)
    if projected == nil then return false, err end
    local candidate, cerr = plan.local_candidate(root, projected)
    if candidate == nil then return false, cerr end
    last_candidate = candidate
    local ok, perr: boolean, string
    if refs.board_mode(root) == "local" then
      ok, perr = refs.update_ref(root, "refs/heads/state", candidate, projected.expected_head)
    else
      ok, perr = prepared.execute(root, push_argv(receipt, candidate))
    end
    if ok then
      receipt.published = candidate
      local saved, serr = staging.write(root, receipt, receipt.sha)
      if saved == nil then return false, "published, but recording returned commit failed: " .. serr end
      return true, "published " .. candidate .. "; confirmation pending"
    end
    if refs.board_mode(root) == "remote" then
      local fetched, ferr = prepared.execute(root, fetch_argv(receipt.remote))
      if not fetched then return false, ferr end
    end
    local current, herr = head(root, receipt.remote)
    if current == nil then return false, herr end
    if current == projected.expected_head then return false, perr end
    if attempt == 5 then
      local final, ferr = inspect_current(root, receipt, last_candidate)
      if final == nil then return false, ferr end
      if final.status == "confirmed" then
        receipt.published = final.candidate
        local saved, serr = staging.write(root, receipt, receipt.sha)
        if saved == nil then return false, "publication proved, but receipt could not be updated: " .. serr end
        return true, "published " .. final.candidate .. "; confirmation pending"
      end
      if not final.absence_proven then return false, "publication is not determined: " .. final.reason end
      return false, lost(root, receipt)
    end
  end
  return false, lost(root, receipt)
end
local function refresh(root: string, remote: string): boolean, string
  local all, err = staging.list(root)
  if all == nil then return false, err end
  local current, herr = head(root, remote)
  if current == nil then return false, herr end
  local confirmed, pending, conflicts, lost_races = 0, 0, 0, 0
  for _, receipt in ipairs(all) do
    local valid, verr = binding(root, receipt, remote)
    if not valid then return false, verr end
    if #receipt.transitions == 0 then goto continue end
    local frozen, ferr = staging.frozen(receipt)
    if frozen == nil then return false, ferr end
    local live, lerr = staging.load(root, receipt.ref)
    if live == nil then
      local observed, oerr = refs.read_ref(root, receipt.ref)
      if observed == nil then return false, oerr end
      if observed == refs.ZERO_SHA then goto continue end
      return false, lerr
    end
    local status, serr = proof.inspect(root, current, frozen, receipt.published ~= "" and receipt.published or nil, live.tip)
    if live.sha ~= receipt.sha then pending = pending + 1; goto continue end
    if status == nil then return false, serr end
    if status.status == "confirmed" then
      local removed, rerr = staging.remove(root, receipt)
      if not removed then
        local observed, oerr = refs.read_ref(root, receipt.ref)
        if observed == nil then return false, oerr end
        if observed == receipt.sha then return false, rerr end
        if observed ~= refs.ZERO_SHA then pending = pending + 1; goto continue end
      end
      confirmed = confirmed + 1
    elseif status.status == "conflict" then conflicts = conflicts + 1
    elseif status.absence_proven then
      local candidate, cerr = build(root, receipt, remote)
      if candidate == nil and cerr == store.LOST_RACE then lost_races = lost_races + 1
      else pending = pending + 1 end
    else pending = pending + 1 end
    ::continue::
  end
  if lost_races > 0 then return false, store.LOST_RACE end
  local authority, aerr = stateclaim.authority(root, current)
  if authority == nil then return false, aerr end
  return conflicts == 0, ("confirmed=%d pending=%d conflict=%d\n%s")
  :format(confirmed, pending, conflicts, authority)
end
local function reset(s: store.Store): boolean, string
  local current, err = head(s.root, refs.board_remote(s.root))
  if current == nil then return false, err end
  s.state_head = current; s.state_receipt = ""; s.state_paths = {}; s.state_reads = {}; s.bounded = false
  s.leased_item = {}; s.leased_sha = {}; s.leased_ref = {}; s.touched_at = {}
  return store.close(s)
end
local function sync(s: store.Store, execute_fetch?: boolean, published?: staging.Receipt): boolean, string
  local remote = refs.board_remote(s.root)
  if execute_fetch and refs.board_mode(s.root) == "remote" then
    local ok, err = prepared.execute(s.root, fetch_argv(remote))
    if not ok then return false, err end
  end
  local ok, err = refresh(s.root, remote)
  if not ok and err == store.LOST_RACE and published ~= nil then
    local observed, oerr = inspect_current(s.root, published, published.published)
    if observed == nil then return false, oerr end
    if observed.status == "confirmed" then
      ok, err = true, "publication confirmed; unrelated stale attempts retired"
    end
  end
  local current, herr = head(s.root, remote)
  if current == nil then return false, herr end
  s.state_head = current
  s.state_receipt = ""
  s.state_paths = {}; s.state_reads = {}
  s.leased_item = {}; s.leased_sha = {}; s.leased_ref = {}; s.touched_at = {}
  local _closed, _cerr = store.close(s)
  return ok, err
end
local function publish(s: store.Store, execute_push?: boolean): boolean, string
  if s.state_receipt == "" then return true, "" end
  local receipt, err = staging.load(s.root, s.state_receipt)
  if receipt == nil then
    local retired, rerr = staging.was_retired(s.root, s.state_receipt, s.state_head)
    if rerr ~= "" then return false, rerr end
    if retired then
      local cleared, cerr = reset(s)
      if not cleared then return false, cerr end
      return false, store.LOST_RACE
    end
    return false, err
  end
  if receipt.kind == "draft" then
    s.state_receipt = ""
    return true, "STAGED draft=" .. receipt.id .. " transitions=" .. tostring(#receipt.transitions)
  end
  if refs.board_mode(s.root) == "local" or execute_push then
    local ok, perr = execute(s.root, receipt)
    if not ok then
      if perr == store.LOST_RACE then
        local cleared, cerr = reset(s)
        if not cleared then return false, cerr end
      end
      return false, perr
    end
    return sync(s, execute_push, receipt)
  end
  local projected, perr = build(s.root, receipt)
  if projected == nil then
    if perr == store.LOST_RACE then
      local cleared, cerr = reset(s)
      if not cleared then return false, cerr end
    end
    return false, perr
  end
  local current, herr = head(s.root, receipt.remote)
  if current == nil then return false, herr end
  s.state_head = current; s.state_receipt = ""; s.state_paths = {}; s.state_reads = {}
  s.leased_item = {}; s.leased_sha = {}; s.leased_ref = {}
  local _closed, _cerr = store.close(s)
  return true, "prepared " .. receipt.ref .. "\npublish: gitboard publish " .. receipt.id
  .. " --execute\nNOT PUBLISHED: run publish, then refresh to confirm the complete transition chain"
end
local record Module
  head: function(string, string): string | nil, string
  fetch_argv: function(string): {string}
  build: function(root: string, receipt: staging.Receipt, remote?: string): plan.Plan | nil, string
  push_argv: function(staging.Receipt, string): {string}
  execute: function(string, staging.Receipt): boolean, string
  refresh: function(string, string): boolean, string
  sync: function(s: store.Store, execute_fetch?: boolean, published?: staging.Receipt): boolean, string
  publish: function(s: store.Store, execute_push?: boolean): boolean, string
end
local M: Module = {head = head, fetch_argv = fetch_argv, build = build, push_argv = push_argv,
  execute = execute, refresh = refresh, sync = sync, publish = publish}
return M
