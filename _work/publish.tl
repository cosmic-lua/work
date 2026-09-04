--- Publishing a store's pending writes to its remote: the atomic,
--- leased push every `save` queues into `s.pending`, and the
--- lost-race recovery when another writer moved a ref first. A
--- mutation is commit-then-push; a lost push race is detected on the
--- push's own rejection text (`stale info`/`rejected`, never exit
--- code alone — `_work.refs.push_atomic`), and recovered with `git
--- fetch --prune`, which resets every local ref this checkout's mirror
--- refspecs cover to the winner's value. There is no working tree to
--- restore afterward — nothing here ever held one — so the recovery
--- is exactly that one fetch. `history` and `touched_at` read the
--- same refs back; `sync` is the same fetch, standalone. The git
--- identity every call runs under, and the `Store` it runs against,
--- live in `_work.store`; every git command here goes back through
--- its `git`/`git_ok`.
local store = require("_work.store")
local refs = require("_work.refs")

--- One item mutation as git recorded it.
local record Event
  sha: string
  --- ISO 8601 commit time.
  at: string
  subject: string
end

--- Whether the store has an `origin` remote to publish to. A store
--- without one is local-only: it publishes trivially, and the gates
--- that ask GitHub about a pull request have nothing to ask.
--- @param s store.Store The store
--- @return boolean True when origin exists
local function has_origin(s: store.Store): boolean
  local r = store.git(s, {"remote"})
  return r ~= nil and r.ok and r.stdout:find("origin", 1, true) ~= nil
end

--- Pull concurrent state: a store with no origin is local-only and
--- syncs trivially; one with an origin fetches with `--prune`, which
--- resets every mirrored ref (`refs/items`, `refs/ended`,
--- `refs/board`) to what the remote holds. There is no working tree
--- to merge into, so this is the whole of sync.
--- @param s store.Store The store
--- @return boolean True on success
--- @return string Error message
local function sync(s: store.Store): boolean, string
  if not has_origin(s) then
    return true
  end
  return refs.fetch_prune(s.root)
end

--- Publish every ref the pending saves touched, in one atomic push
--- leased against the tip each was observed at. Rejection is
--- diagnosed from the push's own text: a `stale info`/`rejected`
--- refusal means a concurrent writer moved a ref this mutation leased
--- — nothing is replayed, since the gates that decided this mutation
--- may no longer hold against the winner's state — so the checkout is
--- re-synced with `fetch --prune` and the refusal is `store.LOST_RACE`,
--- whose recovery is re-running the verb against the merged board. A
--- rejection that names something else — a pre-receive hook, a
--- read-only token — is policy, not a race: the local commits and the
--- pending push both stay exactly as they are, so a caller can fix
--- the policy problem and publish again without redoing the mutation.
--- @param s store.Store The store
--- @return boolean True once every pending ref landed (or there was
--- nothing to push)
--- @return string Error message; `LOST_RACE` exactly, for a lost race
local function publish(s: store.Store): boolean, string
  if not has_origin(s) or #s.pending == 0 then
    s.pending = {}
    return true
  end
  local ok, stale, err = refs.push_atomic(s.root, s.pending)
  if ok then
    s.pending = {}
    return true
  end
  if not stale then
    return false, ("the push was rejected, and not by a concurrent "
      .. "mutation — the commit is still local; the remote said: %s"):format(err)
  end
  s.pending = {}
  s.leased_ref = {}
  s.leased_sha = {}
  -- A cleared lease means "unobserved" to the fast-import diff too
  -- (`_work.gitwrite.plan_one` reads `leased_item[id]`): a snapshot
  -- surviving this reset would go on comparing a re-run's item
  -- against a ref `fetch_prune` may have just pruned out from under
  -- it, silently treating real fields as unchanged and skipping the
  -- `meta` write a brand-new root commit still needs.
  s.leased_item = {}
  local synced, serr = refs.fetch_prune(s.root)
  if not synced then
    return false, ("lost the push race — the mutation was dropped whole, "
      .. "and the re-sync then stopped: %s"):format(serr)
  end
  -- The next bounded save's lease has to be the tip this fetch just
  -- landed, not whatever `s.observed_seq` held before it — otherwise a
  -- re-run's own bounded save would lease against a value the remote
  -- has already moved past, losing a race against itself.
  local seq_found, sferr = refs.for_each_ref(s.root, {"refs/board/seq"})
  if seq_found == nil then
    return false, ("lost the push race — the mutation was dropped whole, "
      .. "and refs/board/seq could not be re-read: %s"):format(sferr)
  end
  s.observed_seq = ""
  if #seq_found > 0 then
    s.observed_seq = seq_found[1].sha
  end
  return false, store.LOST_RACE
end

--- Mutation history, newest first: one item's when `id` names one —
--- `git log` on its own ref, O(item) not O(board) — or the whole
--- board's, merged across every item and ended ref, when it does not.
--- @param s store.Store The store
--- @param id string Item id, or nil for every commit on every ref
--- @return {Event} | nil Events, possibly empty
--- @return string Error message
local function history(s: store.Store, id?: string): {Event} | nil, string
  local argv: {string} = {"log", "--format=%h\t%cI\t%s"}
  if id ~= nil then
    local ref = s.leased_ref[id]
    if ref == nil then
      local found, ferr = refs.for_each_ref(s.root,
        {"refs/items/" .. id, "refs/ended/" .. id})
      if found == nil then
        return nil, ferr
      end
      if #found == 0 then
        return nil, ("no item %s"):format(id)
      end
      ref = found[1].refname
    end
    argv[#argv + 1] = ref
  else
    local found, ferr = refs.for_each_ref(s.root, {"refs/items", "refs/ended"})
    if found == nil then
      return nil, ferr
    end
    if #found == 0 then
      return {}
    end
    for _, r in ipairs(found) do
      argv[#argv + 1] = r.refname
    end
  end
  local r, err = store.git_ok(s, argv)
  if r == nil then
    return nil, err
  end
  local out: {Event} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    local sha, at, subject = line:match("^(%S+)\t(%S+)\t(.*)$")
    if sha then
      out[#out + 1] = {sha = sha, at = at, subject = subject}
    end
  end
  return out
end

--- When an item's ref was last committed, as epoch seconds — the fact
--- claim staleness is judged from (`_work.health`).
--- @param s store.Store The store
--- @param id string Item id
--- @return integer | nil Epoch seconds of the last commit on its ref
--- @return string Error message, also when it has no history
local function touched_at(s: store.Store, id: string): integer | nil, string
  local ref = s.leased_ref[id]
  if ref ~= nil then
    return refs.committer_date_unix(s.root, ref)
  end
  local t, terr = refs.committer_date_unix(s.root, "refs/items/" .. id)
  if t ~= nil then
    return t
  end
  local t2, terr2 = refs.committer_date_unix(s.root, "refs/ended/" .. id)
  if t2 ~= nil then
    return t2
  end
  return nil, terr2 or terr
end

local record publish_module
  type Event = Event
  has_origin: function(s: store.Store): boolean
  sync: function(s: store.Store): boolean, string
  publish: function(s: store.Store): boolean, string
  history: function(s: store.Store, id?: string): {Event} | nil, string
  touched_at: function(s: store.Store, id: string): integer | nil, string
end

local M: publish_module = {
  has_origin = has_origin,
  sync = sync,
  publish = publish,
  history = history,
  touched_at = touched_at,
}

return M
