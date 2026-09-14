--- Native board store over one immutable state head per invocation.
--- Git objects remain truth; SQLite is a disposable query projection.
--- Item and history reads are memoized by head; caller Items are independent copies.
--- Native transitions are prepared by statewrite and published by statepublish.
local stateread_start = require("_work.stateread_start")
local boardhistory = require("_work.boardhistory")
local stateread_clock = require("_work.stateread_clock")
local boardread = require("_work.boardread")
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local cachequery = require("_work.cachequery")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local itemtree = require("_work.itemtree")
local item = require("_work.item")
local refs = require("_work.refs")
local stateinit = require("_work.stateinit")
local storeitem = require("_work.storeitem")

--- Invocation-local observations. state_head names the snapshot and state_receipt
--- a prepared successor. leased_item is independent of caller mutations;
--- touched_at and leased_sha retain exact path-attributed history.
---
--- The two native path tables differ deliberately. `state_paths` is every
--- `items/<id>`/`claims/<id>` OID a whole-board read LOADED, so a later
--- decision can look one up without another Git process. `state_reads` is the
--- FENCE: only the paths a mutation read to DECIDE, which publication compares
--- between its staging base and the fetched head. Fencing everything a read
--- touched would make every pair of writers conflict — the cost one branch
--- exists to avoid; a mutation whose GATE reads beyond the items it writes is
--- protected by re-running that gate against the fetched head instead
--- (`_work.stategate`).
---
--- remote_url/remote_present memoize ad hoc Git remote discovery within this
--- invocation. Their read flags distinguish an unasked question from an empty or
--- failed result; they do not memoize mutable board state across snapshots.
local record Store
  native_view: boardread.View | nil
  native_history: boardhistory.History | nil
  native_history_head: string
  startup: stateread_start.Start | nil
  root: string
  state_head: string
  state_receipt: string
  state_paths: {string: string}
  state_reads: {string: string}
  session: string
  op: string
  bounded: boolean
  leased_ref: {string: string}
  leased_sha: {string: string}
  leased_item: {string: item.Item}
  touched_at: {string: integer}
  --- The epoch second the most recent `save` stamped on its commits;
  --- 0 before any save.
  written_at: integer
  board_digest: string
  fresh_lease: string
  remote_url: string
  remote_url_ok: boolean
  remote_url_read: boolean
  remote_present: boolean
  remote_present_read: boolean
  --- The board cache, opened once and held for the rest of this
  --- invocation — `read`'s own handle, and what `list` hydrates
  --- `leased_ref`/`leased_sha`/`touched_at`/`board_digest` from. nil
  --- before the first `read`/`list` call, or once `close` has run.
  --- Every `_work.read` call a verb makes goes through this same
  --- connection, never a fresh `cache.open` of its own.
  index: cache.Cache | nil
end

--- The refusal a lost push race earns, exported so a verb can tell it
--- from a terminal failure; compared by identity, never matched.
local LOST_RACE < const > = "lost the push race — the mutation was dropped "
.. "whole and the checkout re-synced; re-run the verb against the "
.. "current board"

--- The fixed prefix a no-op `save` carries, so `is_noop` can tell one
--- from an ordinary success or a terminal failure without matching
--- the whole message.
local NOOP_PREFIX < const > = "nothing to record: "

--- Whether an outcome from `save` (or a caller built on it, like
--- `_work.gitgate.commit_and_publish`) is the no-op success.
--- @param detail string The message returned alongside a truthy `save`
--- @return boolean True on a no-op success
local function is_noop(detail: string): boolean
  return (detail or ""):sub(1, #NOOP_PREFIX) == NOOP_PREFIX
end

--- Git defaults for the ad hoc commands this module and `_work.publish`
--- still run directly (`remote`, `push`, `fetch`, ...): a deterministic
--- identity for anything that happens to create an object, and
--- rename-based object finalization — link-based finalization fails
--- with EXDEV on the overlay/bind mounts CI containers run tests on.
local GIT_DEFAULTS: {string} = {
  "-c", "user.email=noreply@anthropic.com", "-c", "user.name=Claude",
  "-c", "core.createObject=rename",
}

--- Run one git command in the store's root.
--- @param s Store The store
--- @param argv {string} Arguments after "git"
--- @return child.Result | nil The finished run, whatever its exit
--- @return string Error message when git could not be started
local function git(s: Store, argv: {string}): child.Result | nil, string
  local full: {string} = {"git"}
  for _, a in ipairs(GIT_DEFAULTS) do
    full[#full + 1] = a
  end
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  return child.run(full, {cwd = s.root})
end

--- Run one git command that must succeed.
--- @param s Store The store
--- @param argv {string} Arguments after "git"
--- @return child.Result | nil The zero-exit run
--- @return string Error message naming the command and its stderr
local function git_ok(s: Store, argv: {string}): child.Result | nil, string
  local r, err = git(s, argv)
  if r == nil then
    return nil, err
  end
  if not r.ok then
    local detail = (r.stderr or ""):gsub("%s+$", "")
    if detail == "" then
      detail = (r.stdout or ""):gsub("%s+$", "")
    end
    return nil, ("git %s failed: %s"):format(table.concat(argv, " "), detail)
  end
  return r
end

--- Open a state repository checkout. The root must be a git
--- repository — `gitboard init` (`init_repo`) creates one.
--- @param root string Checkout root
--- @return Store | nil The store
--- @return string Error message
local function open(root: string): Store | nil, string
  if not fs.is_present(fs.join(root, ".git")) then
    return nil, ("not a git repository: %s"):format(root)
  end
  local startup, err = stateread_start.open(root)
  if startup == nil then return nil, err end
  return {root = root, native_view = nil, native_history = nil, native_history_head = "", startup = startup, state_head = startup.head, state_receipt = "", state_paths = {}, state_reads = {}, session = "", op = "", bounded = false, leased_ref = {},
    leased_sha = {}, leased_item = {}, touched_at = {}, written_at = 0,
    board_digest = "", fresh_lease = "",
    remote_url = "", remote_url_ok = false, remote_url_read = false,
    remote_present = false, remote_present_read = false, index = nil}
end

--- Decode an immutable head once per invocation. Expiry changes projection, not history.
local function view(s: Store): boardread.View | nil, string
  local known = s.native_view
  if known ~= nil and known.head == s.state_head then
    local fresh = true
    local now = os.time()
    for _, lease in pairs(known.claims_by_id) do
      if known.projected_at < lease.expires_at and now >= lease.expires_at then fresh = false end
    end
    if fresh then return known, "" end
  end
  local got, err = boardread.list(s.root, s.state_head)
  if got == nil then return nil, err end
  s.native_view = got
  return got, ""
end

local function history(s: Store): boardhistory.History | nil, string
  local known = s.native_history
  if known ~= nil and s.native_history_head == s.state_head then return known, "" end
  local got, err = boardhistory.read(s.root, s.state_head)
  if got == nil then return nil, err end
  s.native_history, s.native_history_head = got, s.state_head
  return got, ""
end

local function resolve(s: Store, prefix: string): string | nil, string
  if prefix == nil or prefix == "" or prefix:match("^%w+$") == nil then
    return nil, ("not an id prefix: %s"):format(tostring(prefix))
  end
  local snapshot, err = view(s)
  if snapshot == nil then return nil, err end
  local matches: {string} = {}
  for _, it in ipairs(snapshot.items) do
    if it.id:sub(1, #prefix) == prefix then matches[#matches + 1] = it.id end
  end
  if #matches == 1 then return matches[1], "" end
  if #matches == 0 then return nil, "no item matches " .. prefix end
  return nil, prefix .. " is ambiguous: " .. table.concat(matches, " ")
end

local function read_spec(s: Store, id: string): itemtree.Spec
  local snapshot, err = view(s)
  -- throws: prose reads must never disguise an unreadable native tree as empty.
  if snapshot == nil then error(err, 0) end
  local spec = snapshot.specs_by_id[id]
  return {change = spec and spec.change or "", non_goals = spec and spec.non_goals or ""}
end
local function read_specs(s: Store, ids: {string}): {string: itemtree.Spec}
  local out: {string: itemtree.Spec} = {}
  for _, id in ipairs(ids) do out[id] = read_spec(s, id) end
  return out
end
local function load_item(s: Store, id: string): item.Item | nil, string
  local snapshot, err = view(s)
  if snapshot == nil then return nil, err end
  local it = snapshot.items_by_id[id]
  if it == nil then return nil, "no item " .. id end
  local events, herr = history(s)
  if events == nil then return nil, herr end
  s.leased_ref[id], s.leased_sha[id] = "refs/heads/state", events.tip_by_id[id] or s.state_head
  s.state_paths["items/" .. id] = snapshot.item_tree_by_id[id]
  s.state_paths["claims/" .. id] = snapshot.claim_blob_by_id[id] or refs.ZERO_SHA
  s.state_reads["items/" .. id] = s.state_paths["items/" .. id]
  s.state_reads["claims/" .. id] = s.state_paths["claims/" .. id]
  s.leased_item[id] = storeitem.snapshot(it)
  s.touched_at[id] = events.touched_by_id[id] or 0
  return storeitem.snapshot(it), ""
end

--- One cache handle per invocation. The first read consumes open's canonical
--- snapshot and scoped batch reader; later reads take a fresh ref snapshot when
--- reopening. Native clock expiry invalidates an otherwise unchanged head.
local function ensure_index(s: Store): cache.Cache | nil, string
  local existing = s.index
  if existing ~= nil then
    if stateread_clock.fresh(existing.db) then return existing, "" end
    local closed, err = cache.close(existing)
    if not closed then return nil, err end
    s.index = nil
  end
  local startup = s.startup
  s.startup = nil
  local found: {refs.RefEntry} | nil = startup and startup.snapshot
  if found == nil then
    -- After a write or clock expiry the startup snapshot has been consumed.
    -- Native rebuilds still need the exact state ref in this fresh snapshot.
    local patterns: {string} = {}
    for _, pattern in ipairs(cachedb.WATCH_PATTERNS) do patterns[#patterns + 1] = pattern end
    if s.state_head ~= "" then patterns[#patterns + 1] = "refs/heads/state" end
    local fresh, err = refs.for_each_ref(s.root, patterns)
    if fresh == nil then return nil, err end
    found = fresh
  end
  local known_digest = s.state_head ~= "" and s.state_head or cachedb.digest_of(found)
  local c, cerr = cache.open(s.root, known_digest, found, startup and startup.reader,
    function(rebuilt_view: boardread.View, rebuilt_history: boardhistory.History)
      s.native_view = rebuilt_view
      s.native_history, s.native_history_head = rebuilt_history, rebuilt_view.head
    end)
  local cleaned, clean_err = stateread_start.close(startup)
  if not cleaned then
    if c ~= nil then local _ok, _err = cache.close(c) end
    return nil, clean_err
  end
  if c == nil then
    return nil, cerr
  end
  if s.state_head ~= "" and cachedb.meta_get(c.db, "refs_digest") ~= s.state_head then
    local _ok, _err = cache.close(c)
    return nil, "board moved while reading; re-run the command"
  end
  s.index = c
  s.board_digest = known_digest
  return c, ""
end

--- Open/reuse the invocation's clock-valid query projection.
local function read(s: Store): cache.Cache | nil, string
  return ensure_index(s)
end

--- Close the scoped startup reader and the invocation's cache, when present.
local function close(s: Store): boolean, string
  local closed, err = stateread_start.close(s.startup)
  s.startup = nil
  if not closed then return false, err end
  local c = s.index
  if c == nil then
    return true, ""
  end
  s.index = nil
  return cache.close(c)
end

--- Every item, including completed work, from the invocation query projection.
--- The rows retain each item’s path-attributed tip and timestamp.
--- @param s Store The store
--- @return {item.Item} | nil The items, some possibly flagged
--- @return string Error message naming the first genuinely corrupt item
local function list(s: Store): {item.Item} | nil, string
  local c, cerr = ensure_index(s)
  if c == nil then
    return nil, cerr
  end
  local all, ierr = cachequery.items(c)
  if all == nil then
    return nil, ierr
  end
  local ls, lerr = cachequery.leases(c)
  if ls == nil then
    return nil, lerr
  end

  for id, ref in pairs(ls.refs_by_id) do
    s.leased_ref[id] = ref
    s.leased_sha[id] = ls.shas_by_id[id]
    s.touched_at[id] = ls.touched_at[id]
  end
  for _, it in ipairs(all) do
    s.leased_item[it.id] = storeitem.snapshot(it)
  end
  if s.state_head ~= "" then
    -- Loaded, not fenced: see the `Store` doc on the two path tables.
    local paths, perr = c.db:query("SELECT path,oid FROM state_paths")
    if paths == nil then return nil, perr end
    for row in paths do s.state_paths[row.path as string] = row.oid as string end -- cast: from any (strict SQLite text columns)
  end
  return all
end

--- Validate an item well enough to write. `_work.storewrite.save` calls
--- this itself for `it` and every `also` item before touching any
--- object; kept as its own function since it is also how a caller
--- checks a hand-built record without writing it.
--- @param s Store The store
--- @param it item.Item The item
--- @param _spec string | nil Unused; kept for signature compatibility
--- @return boolean True when the item may be written
--- @return string Error message
local function stage(s: Store, it: item.Item, _spec?: string): boolean, string
  local closed, err = stateread_start.close(s.startup)
  s.startup = nil
  if not closed then return false, err end
  local bad = item.problems(it)
  if #bad > 0 then
    return false, table.concat(bad, "; ")
  end
  return true, ""
end

local record store
  view: function(s: Store): boardread.View | nil, string
  history: function(s: Store): boardhistory.History | nil, string
  type Store = Store
  LOST_RACE: string
  NOOP_PREFIX: string
  is_noop: function(detail: string): boolean
  git: function(s: Store, argv: {string}): child.Result | nil, string
  git_ok: function(s: Store, argv: {string}): child.Result | nil, string
  init_repo: function(dir: string): boolean, string
  open: function(root: string): Store | nil, string
  load: function(s: Store, id: string): item.Item | nil, string
  resolve: function(s: Store, prefix: string): string | nil, string
  read_spec: function(s: Store, id: string): itemtree.Spec
  read_specs: function(s: Store, ids: {string}): {string: itemtree.Spec}
  snapshot_item: function(it: item.Item): item.Item | nil
  list: function(s: Store): {item.Item} | nil, string
  read: function(s: Store): cache.Cache | nil, string
  close: function(s: Store): boolean, string
  flagged_summary: function(items: {item.Item}): string
  stage: function(s: Store, it: item.Item, spec?: string): boolean, string
end

local M: store = {
  view = view, history = history,
  LOST_RACE = LOST_RACE,
  NOOP_PREFIX = NOOP_PREFIX,
  is_noop = is_noop,
  git = git,
  git_ok = git_ok,
  init_repo = stateinit.init,
  open = open,
  load = load_item,
  resolve = resolve,
  read_spec = read_spec,
  read_specs = read_specs,
  snapshot_item = storeitem.snapshot,
  list = list,
  read = read,
  close = close,
  flagged_summary = storeitem.flagged_summary,
  stage = stage,
}

return M
