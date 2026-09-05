--- Publishing a store's pending writes to its remote: the atomic,
--- leased push every `save` queues into `s.pending`, and the
--- lost-race recovery when another writer moved a ref first. A
--- mutation is commit-then-push; a lost push race is detected on the
--- push's own rejection text (`stale info`/`rejected`, never exit
--- code alone — `_work.refs.push_atomic`), and recovered with `git
--- fetch --prune`, which resets every local ref this checkout's mirror
--- refspecs cover to the winner's value. There is no working tree to
--- restore afterward — nothing here ever held one — so the recovery
--- is exactly that one fetch. `history` reads the `events` cache when
--- it is current, falling back to the same `git log` `touched_at`
--- still always uses; `sync` is the fetch, standalone. The git
--- identity every call runs under, and the `Store` it runs against,
--- live in `_work.store`; every git command here goes back through
--- its `git`/`git_ok`.
local cache = require("_work.cache")
local events = require("_work.events")
local store = require("_work.store")
local refs = require("_work.refs")

--- One item mutation as git recorded it.
local record Event
  sha: string
  --- UTC, `YYYY-MM-DDTHH:MM:SSZ` — the same `Z`-suffixed form
  --- `_work.gitshow`'s own `opened:` line prints, and (see `history`'s
  --- own doc comment) rendered the same way regardless of source, so
  --- it never depends on the host's git version or its `TZ`.
  at: string
  subject: string
end

--- Whether the store has an `origin` remote to publish to. A store
--- without one is local-only: it publishes trivially, and the gates
--- that ask GitHub about a pull request have nothing to ask. Memoized
--- on `s` — `git remote` never changes within one run, and this is
--- asked more than once in some verbs (`sync`, then `publish`, then a
--- verb's own pre-check), so only the first ask ever spawns it.
--- @param s store.Store The store
--- @return boolean True when origin exists
local function has_origin(s: store.Store): boolean
  if not s.remote_present_read then
    local r = store.git(s, {"remote"})
    s.remote_present = r ~= nil and r.ok and r.stdout:find("origin", 1, true) ~= nil
    s.remote_present_read = true
  end
  return s.remote_present
end

--- Pull concurrent state: a store with no origin is local-only and
--- syncs trivially; one with an origin fetches with `--prune`, which
--- resets every mirrored ref (`refs/heads/items`, `refs/heads/ended`,
--- `refs/heads/board`) to what the remote holds. There is no working tree
--- to merge into, so this is the whole of sync.
--- @param s store.Store The store
--- @return boolean True on success
--- @return string Error message
local function sync(s: store.Store): boolean, string
  if not has_origin(s) then
    return true
  end
  local specs_ok, serr = refs.ensure_refspecs(s.root)
  if not specs_ok then
    return false, serr
  end
  return cache.around_fetch(s.root, function(): boolean, string
      return refs.fetch_prune(s.root)
    end)
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
  -- Same reasoning as the lease reset above: a snapshot's committer
  -- date is only as trustworthy as the ref it was read from, and
  -- `fetch_prune` is about to move that ref out from under it.
  s.touched_at = {}
  local synced, serr = cache.around_fetch(s.root, function(): boolean, string
      return refs.fetch_prune(s.root)
    end)
  if not synced then
    return false, ("lost the push race — the mutation was dropped whole, "
      .. "and the re-sync then stopped: %s"):format(serr)
  end
  -- The next bounded save's lease has to be the tip this fetch just
  -- landed, not whatever `s.observed_seq` held before it — otherwise a
  -- re-run's own bounded save would lease against a value the remote
  -- has already moved past, losing a race against itself.
  local seq_found, sferr = refs.for_each_ref(s.root, {"refs/heads/board/seq"})
  if seq_found == nil then
    return false, ("lost the push race — the mutation was dropped whole, "
      .. "and refs/heads/board/seq could not be re-read: %s"):format(sferr)
  end
  s.observed_seq = ""
  if #seq_found > 0 then
    s.observed_seq = seq_found[1].sha
  end
  return false, store.LOST_RACE
end

--- The fixed width `history` abbreviates every sha to, on both paths —
--- the same "gitboard renders its own, rather than trusting the git
--- binary installed" decision `iso8601_z` makes for the timestamp:
--- `%h`'s width is `core.abbrev`'s call, live and per-repository, so a
--- cache path abbreviating to whatever git would choose either asks
--- git directly (a process this table exists to avoid) or risks
--- disagreeing with a later `%h` read as the repository grows past 7
--- hex digits' worth of objects. This project's boards are nowhere
--- near that scale, so a fixed 7 — git's own historical floor, and
--- what `%h` gives on every board this ratchet has run against — is
--- the simpler, git-version-independent choice.
local ABBREV_LEN < const > = 7

--- One epoch, rendered `YYYY-MM-DDTHH:MM:SSZ` — the single formatter
--- `history` runs EVERY commit time through, cache-sourced or
--- git-sourced alike (see `history`'s own doc comment for why: `%cI`
--- prints a different suffix on a different git version for the exact
--- same UTC instant, which a byte-identical render cannot tolerate).
--- `!` forces `os.date` to UTC regardless of the host's own `TZ`, the
--- same call `_work.gitshow`'s `opened:` line already makes.
--- @param epoch integer Unix seconds
--- @return string The UTC timestamp
local function iso8601_z(epoch: integer): string
  return os.date("!%Y-%m-%dT%H:%M:%SZ", epoch) as string -- cast: os.date with a format string always returns string
end

--- `history`'s cache path: `_work.events.read`, newest first, with
--- each row's sha abbreviated and epoch rendered exactly as the
--- `git log` fallback below would — nil (never a second-class empty
--- result) on anything this cache cannot answer, which `history` reads
--- as "fall through to the git log instead."
--- @param s store.Store The store
--- @param id string Item id
--- @return {Event} | nil Newest-first events, nil to fall through
local function events_from_cache(s: store.Store, id: string): {Event} | nil
  local rows = events.read(s.root, id)
  if rows == nil or #rows == 0 then
    return nil
  end
  local out: {Event} = {}
  for i = #rows, 1, -1 do
    local row = rows[i]
    out[#out + 1] = {sha = row.sha:sub(1, ABBREV_LEN), at = iso8601_z(row.at),
      subject = row.subject}
  end
  return out
end

--- Mutation history, newest first: one item's when `id` names one —
--- from the `events` cache when it is current, `git log` on its own
--- ref (O(item) not O(board)) otherwise — or the whole board's, merged
--- across every item and ended ref, when `id` is nil (always `git
--- log`; the cache carries no whole-board query for this).
---
--- FORMAT: both `sha` and `at` are rendered by ONE Lua path regardless
--- of source, cache or fallback — `at` is `iso8601_z` run over `%ct`
--- (raw epoch seconds), never git's own `%cI` (a different offset
--- suffix on a different git version for the exact same UTC instant,
--- `+00:00` vs. `Z`, which a byte-identical render cannot tolerate);
--- `sha` is `%H` (the full hash) sliced to `ABBREV_LEN` in Lua, never
--- git's own `%h` (whose abbreviation width is `core.abbrev`'s live
--- call, not a fixed fact this table could store and reproduce
--- exactly). Either divergence would make `show ID`'s history block
--- a fact of the git binary installed rather than of the commits
--- themselves; routing both through the same formatters instead makes
--- it `Z`-form UTC with 7-hex shas unconditionally — the timestamp
--- form matching `_work.gitshow`'s own `opened:` line — and costs the
--- fallback nothing extra: `%H` is no more expensive to print than
--- `%h`, and the cache path now spawns no git process of its own at
--- all for a `show ID` served warm.
--- @param s store.Store The store
--- @param id string Item id, or nil for every commit on every ref
--- @return {Event} | nil Events, possibly empty
--- @return string Error message
local function history(s: store.Store, id?: string): {Event} | nil, string
  local cached: {Event} | nil = nil
  if id ~= nil then
    cached = events_from_cache(s, id)
  end
  if cached ~= nil then
    return cached
  end
  local argv: {string} = {"log", "--format=%H\t%ct\t%s"}
  if id ~= nil then
    local ref = s.leased_ref[id]
    if ref == nil then
      local found, ferr = refs.for_each_ref(s.root,
        {"refs/heads/items/" .. id, "refs/heads/ended/" .. id})
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
    local found, ferr = refs.for_each_ref(s.root, {"refs/heads/items", "refs/heads/ended"})
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
    local sha, at_str, subject = line:match("^(%S+)\t(%S+)\t(.*)$")
    if sha and at_str then
      local at = math.tointeger(tonumber(at_str))
      if at then
        out[#out + 1] = {sha = sha:sub(1, ABBREV_LEN), at = iso8601_z(at), subject = subject}
      end
    end
  end
  return out
end

--- When an item's ref was last committed, as epoch seconds — the fact
--- claim staleness is judged from (`_work.health`). Read from
--- `s.touched_at` when a caller already took a ref snapshot that
--- named this id (`_work.gitview.list_via_cache`'s own digest
--- snapshot, say) — the common case for a board-wide render, where it
--- costs nothing beyond the snapshot already paid for. The per-ref
--- `committer_date_unix` process below is the fallback, run only for
--- an id no such snapshot carried (a fresh store nothing has listed
--- yet).
--- @param s store.Store The store
--- @param id string Item id
--- @return integer | nil Epoch seconds of the last commit on its ref
--- @return string Error message, also when it has no history
local function touched_at(s: store.Store, id: string): integer | nil, string
  local known = s.touched_at[id]
  if known ~= nil then
    return known
  end
  local ref = s.leased_ref[id]
  if ref ~= nil then
    return refs.committer_date_unix(s.root, ref)
  end
  local t, terr = refs.committer_date_unix(s.root, "refs/heads/items/" .. id)
  if t ~= nil then
    return t
  end
  local t2, terr2 = refs.committer_date_unix(s.root, "refs/heads/ended/" .. id)
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
