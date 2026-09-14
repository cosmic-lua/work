--- Native state publication: immutable plans, bounded retries and content proof.
local stateclaim = require("_work.stateclaim")
local stategate = require("_work.stategate")
local refs = require("_work.refs")
local prepared = require("_work.prepared")
local staging = require("_work.statestaging")
local tx = require("_work.statetransaction")
local plan = require("_work.stateplan")
local proof = require("_work.stateplan_receipts")
local store = require("_work.store")
local cache = require("_work.cache")
--- The board head a publication races against: the branch itself in local
--- mode, the tracking ref in remote mode — never a prepared local successor.
--- @param root string The board checkout
--- @param remote string The configured board remote
--- @return string | nil The head, `ZERO_SHA` on a board with none
--- @return string Error message
local function head(root: string, remote: string): string | nil, string
  local ref = refs.board_mode(root) == "local" and "refs/heads/state" or "refs/remotes/" .. remote .. "/state"
  return refs.read_ref(root, ref)
end
--- The fetch a native board needs: exactly the two refs a reader activates on,
--- atomically, so `state` and its marker never land apart.
--- @param remote string The configured board remote
--- @return {string} The argv to run
local function fetch_argv(remote: string): {string}
  return {"git", "fetch", "--atomic", remote,
    "+refs/heads/state:refs/remotes/" .. remote .. "/state",
    "+refs/heads/board/format:refs/remotes/" .. remote .. "/board/format"}
end
--- Whether this checkout still points where the attempt was frozen for — the
--- remote, the repository identity and the exact push URL. Re-checked before
--- every push and on every refresh, so a receipt cannot be published to a
--- destination it was never bound to.
--- @param root string The board checkout
--- @param receipt staging.Receipt The attempt
--- @param remote string | nil A remote the caller requires it to match
--- @return boolean True when the binding still holds
--- @return string Which part of the destination differs
local function binding(root: string, receipt: staging.Receipt, remote?: string): boolean, string
  if remote ~= nil and remote ~= receipt.remote then return false, "prepared transaction destination differs" end
  if staging.repository(root, receipt.remote) ~= receipt.repository then return false, "prepared repository destination differs" end
  if staging.target_url(root, receipt.remote) ~= receipt.target_url then return false, "prepared remote URL differs" end
  return true, ""
end
--- What the fetched head says about this attempt: confirmed, in conflict, or
--- pending — and, when pending, whether its ABSENCE is proven, which is what
--- makes another push attempt safe rather than a possible duplicate.
--- @param root string The board checkout
--- @param receipt staging.Receipt The attempt
--- @param known string | nil A candidate sha this session just pushed
--- @return proof.Status | nil What the head proves
--- @return string Error message
local function inspect_current(root: string, receipt: staging.Receipt, known?: string): proof.Status | nil, string
  local current, err = head(root, receipt.remote)
  if current == nil then return nil, err end
  local frozen, ferr = staging.frozen(receipt)
  if frozen == nil then return nil, ferr end
  return proof.inspect(root, current, frozen, known or (receipt.published ~= "" and receipt.published or nil))
end
--- Drop the receipt whole and return exactly `store.LOST_RACE`, which is the
--- refusal callers compare by identity. A lost race that left the prepared ref
--- behind would fail identically on every retry and make `refresh` ambiguous,
--- so a receipt that cannot be retired says so instead of claiming the race.
--- @param root string The board checkout
--- @param receipt staging.Receipt The attempt that lost
--- @return string `store.LOST_RACE`, or why the receipt was kept
local function lost(root: string, receipt: staging.Receipt): string
  local retired, err = staging.retire(root, receipt)
  if not retired then return "lost race, but receipt was retained: " .. err end
  return store.LOST_RACE
end
--- Preserve the unpublished suffix of a live draft after an immutable snapshot
--- published its exact leading prefix. The receipt ref moves under CAS before
--- the snapshot can be retired, so a crash leaves either the whole old draft
--- or the durable suffix. The speculative tip remains retained unchanged.
--- @param root string The board checkout
--- @param receipt staging.Receipt The exact live draft manifest inspected
--- @param current string The fetched canonical head after the prefix
--- @param count integer Number of published leading transitions
--- @return staging.Receipt | nil The rewritten suffix receipt
--- @return string Error message
local function consume_prefix(root: string, receipt: staging.Receipt,
    current: string, count: integer): staging.Receipt | nil, string
  if receipt.kind ~= "draft" or count < 1 or count >= #receipt.transitions then
    return nil, "invalid published draft prefix"
  end
  local frozen, err = staging.frozen(receipt)
  if frozen == nil then return nil, err end
  local remaining: {tx.Transition} = {}
  for index = count + 1, #frozen.transitions do
    remaining[#remaining + 1] = frozen.transitions[index]
  end
  remaining[1].base = current
  receipt.base = current
  receipt.transitions = remaining
  receipt.published = ""
  local rewritten, werr = staging.write(root, receipt, receipt.sha)
  if rewritten == nil then return nil, werr end
  local active = staging.active(root)
  if active ~= nil and active.ref == receipt.ref and active.sha == receipt.sha then
    staging.activate(root, rewritten)
  end
  return rewritten, ""
end
--- One publishable attempt against the head as it is now: the destination
--- re-checked, an already-published attempt named as such rather than
--- re-pushed, and an undetermined one refused rather than guessed at. A lost
--- fence retires the receipt here, so the caller gets `store.LOST_RACE`.
--- @param root string The board checkout
--- @param receipt staging.Receipt The attempt
--- @param remote string | nil A remote the caller requires it to match
--- @return plan.Plan | nil The plan to publish
--- @return string Error message, or `store.LOST_RACE`
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
--- The non-forced push that publishes `candidate` as the board head.
--- @param receipt staging.Receipt The attempt, for its remote
--- @param candidate string The commit to publish
--- @return {string} The argv to run
local function push_argv(receipt: staging.Receipt, candidate: string): {string}
  return {"git", "push", receipt.remote, candidate .. ":refs/heads/state"}
end
--- Publish one attempt, retrying a MOVED head at most five times: each attempt
--- re-reads the head, re-checks the fence, rebases and pushes non-forced. A
--- rejection is only a lost race once the fence says so; after the fifth
--- attempt the head is inspected once more — a push whose acknowledgement was
--- lost is confirmed rather than retried — and only then is the attempt retired
--- as `store.LOST_RACE`.
--- @param root string The board checkout
--- @param receipt staging.Receipt The attempt to publish
--- @return boolean True when the attempt landed
--- @return string What landed, or the refusal
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
--- Report every outstanding attempt against the fetched head, and claim
--- authority separately from it: a confirmed attempt retires its local ref, a
--- conflicting one is reported and kept, and a draft that advanced since its
--- publication snapshot stays pending rather than being confirmed by it. When
--- `published` names this invocation's attempt, its complete-chain proof alone
--- decides that publication's result; other receipt conflicts remain visible
--- as informational work for a later refresh.
--- Publication is not authority — the current `claims/<id>` blobs are.
--- @param root string The board checkout
--- @param remote string The configured board remote
--- @param published staging.Receipt | nil This invocation's published attempt
--- @return boolean True when nothing conflicts
--- @return string The counts and the current claim authority
local function refresh(root: string, remote: string,
    published?: staging.Receipt): boolean, string
  local all, err = staging.list(root)
  if all == nil then return false, err end
  local listed: {staging.Receipt} = all
  local current, herr = head(root, remote)
  if current == nil then return false, herr end
  local confirmed, pending, conflicts, lost_races = 0, 0, 0, 0
  local consumed: {string: boolean} = {}
  -- Consume every provable live-draft prefix before retiring any confirmed
  -- snapshot. If a receipt CAS fails, every proof receipt is still present and
  -- the next refresh can repeat the decision from durable state.
  for _, receipt in ipairs(listed) do
    if receipt.kind ~= "draft" or #receipt.transitions == 0 then goto next_draft end
    local valid, verr = binding(root, receipt, remote)
    if not valid then return false, verr end
    local live, lerr = staging.load(root, receipt.ref)
    if live == nil then
      local observed, oerr = refs.read_ref(root, receipt.ref)
      if observed == nil then return false, oerr end
      if observed == refs.ZERO_SHA then goto next_draft end
      return false, lerr
    end
    if live.sha ~= receipt.sha then goto next_draft end
    local frozen, ferr = staging.frozen(receipt)
    if frozen == nil then return false, ferr end
    local status, serr = proof.inspect(root, current, frozen,
      receipt.published ~= "" and receipt.published or nil, live.tip)
    if status == nil then return false, serr end
    if status.status == "prefix" then
      local rewritten, rerr = consume_prefix(root, receipt, current, status.prefix)
      if rewritten == nil then return false, "published draft prefix was retained whole: " .. rerr end
      consumed[receipt.ref] = true
    end
    ::next_draft::
  end
  for _, receipt in ipairs(listed) do
    if consumed[receipt.ref] then pending = pending + 1; goto continue end
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
  local own_confirmed = false
  if published ~= nil then
    local own, oerr = inspect_current(root, published, published.published)
    if own == nil then return false, oerr end
    if own.status ~= "confirmed" then
      return false, "publication is not confirmed: " .. own.reason
    end
    own_confirmed = true
  end
  if lost_races > 0 and not own_confirmed then return false, store.LOST_RACE end
  local authority, aerr = stateclaim.authority(root, current)
  if authority == nil then return false, aerr end
  local report = ("confirmed=%d pending=%d conflict=%d\n%s")
  :format(confirmed, pending, conflicts, authority)
  if own_confirmed and (lost_races > 0 or conflicts > 0) then
    return true, "publication confirmed; unrelated receipt warning\n" .. report
  end
  return conflicts == 0, report
end
--- Drop everything this invocation staged or observed and re-sync to the
--- current head — what a lost race leaves behind, so the verb re-reads and
--- decides again rather than retrying against a board that moved.
--- @param s store.Store The open store to re-sync
--- @return boolean True on success
--- @return string Error message
local function reset(s: store.Store): boolean, string
  local current, err = head(s.root, refs.board_remote(s.root))
  if current == nil then return false, err end
  s.state_head = current; s.state_receipt = ""; s.state_paths = {}; s.state_reads = {}; s.bounded = false
  s.leased_item = {}; s.leased_sha = {}; s.leased_ref = {}; s.touched_at = {}
  return store.close(s)
end
--- Fetch when asked, confirm what landed, and leave the store reading the
--- current head. A `LOST_RACE` from an unrelated stale attempt does not mask
--- this session's own publication: `published` is inspected on its own.
--- @param s store.Store The open store
--- @param execute_fetch boolean | nil Whether to run the fetch, not just report it
--- @param published staging.Receipt | nil This session's own attempt, if any
--- @return boolean True when nothing conflicts
--- @return string The refresh report, or the refusal
local function sync(s: store.Store, execute_fetch?: boolean, published?: staging.Receipt): boolean, string
  local remote = refs.board_remote(s.root)
  if execute_fetch and refs.board_mode(s.root) == "remote" then
    local ok, err = prepared.execute(s.root, fetch_argv(remote))
    if not ok then return false, err end
  end
  local ok, err = refresh(s.root, remote, published)
  local current, herr = head(s.root, remote)
  if current == nil then return false, herr end
  s.state_head = current
  s.state_receipt = ""
  s.state_paths = {}; s.state_reads = {}
  s.leased_item = {}; s.leased_sha = {}; s.leased_ref = {}; s.touched_at = {}
  local _closed, _cerr = store.close(s)
  cache.after_fetch(s.root, current)
  return ok, err
end
--- Publish whatever this invocation prepared. A draft is staged, not published;
--- a local board publishes at once; a remote board prepares and prints the
--- command that publishes, because a real push is the caller's decision. A lost
--- race resets the store before returning `store.LOST_RACE`.
--- @param s store.Store The open store carrying the prepared receipt
--- @param execute_push boolean | nil Whether to push now on a remote board
--- @return boolean True on success, including "prepared, not published"
--- @return string What happened, or `store.LOST_RACE`
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
  refresh: function(string, string, published?: staging.Receipt): boolean, string
  sync: function(s: store.Store, execute_fetch?: boolean, published?: staging.Receipt): boolean, string
  publish: function(s: store.Store, execute_push?: boolean): boolean, string
end
local M: Module = {head = head, fetch_argv = fetch_argv, build = build, push_argv = push_argv,
  execute = execute, refresh = refresh, sync = sync, publish = publish}
return M
