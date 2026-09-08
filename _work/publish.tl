--- Publication planning and confirmation. A mutation becomes a
--- Git-native prepared transaction; by default its exact atomic
--- leased push and fetch commands are returned to the caller and no
--- remote I/O occurs. An explicit execution flag runs those ordinary
--- Git commands with caller-configured credentials. `sync` likewise
--- refreshes from already-fetched remote-tracking refs unless
--- explicitly asked to execute the rendered fetch. History remains a
--- local Git/cache read.
local events = require("_work.events")
local prepared = require("_work.prepared")
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

--- Whether the store has its configured board remote. A store
--- without one is local-only: it publishes trivially, and the gates
--- that ask GitHub about a pull request have nothing to ask. Memoized
--- on `s` — `git remote` never changes within one run, and this is
--- asked more than once in some verbs (`sync`, then `publish`, then a
--- verb's own pre-check), so only the first ask ever spawns it.
--- @param s store.Store The store
--- @return boolean True when the configured remote exists
local function has_origin(s: store.Store): boolean
  if not s.remote_present_read then
    local r = store.git(s, {"remote"})
    local wanted = refs.board_remote(s.root)
    s.remote_present = r ~= nil and r.ok
    and ("\n" .. r.stdout .. "\n"):find("\n" .. wanted .. "\n", 1, true) ~= nil
    s.remote_present_read = true
  end
  return s.remote_present
end

--- Confirm prepared transactions against refs the caller has already
--- fetched. With `execute=true`, first run the exact ordinary Git
--- fetch command using the caller's configured credentials.
--- @param s store.Store The store
--- @return boolean True on success
--- @return string Error message
local function sync(s: store.Store, execute?: boolean): boolean, string
  local remote = refs.board_remote(s.root)
  if execute and refs.board_mode(s.root) == "remote" then
    local fetched, ferr = prepared.execute(s.root, prepared.fetch_argv(remote))
    if not fetched then
      return false, ferr
    end
  end
  local results, err = prepared.refresh(s.root, remote)
  if results == nil then
    return false, err
  end
  local _cok, _cerr = store.close(s)
  local pending_count, lost_count = 0, 0
  for _, result in ipairs(results) do
    if result.state == "pending" then
      pending_count = pending_count + 1
    elseif result.state == "lost-race" then
      lost_count = lost_count + 1
    end
  end
  if lost_count > 0 then
    return false, ("%d prepared transaction(s) lost their ref lease; "
      .. "they remain under refs/gitboard/prepared for inspection"):format(lost_count)
  end
  if pending_count > 0 then
    return true, ("%d prepared transaction(s) are not confirmed; fetch with: %s")
    :format(pending_count, table.concat(prepared.fetch_argv(remote), " "))
  end
  if not execute and refs.board_mode(s.root) == "remote" then
    return true, "refresh inspected fetched refs only; to fetch first, run: "
    .. table.concat(prepared.fetch_argv(remote), " ")
  end
  return true, "state is current"
end

--- Convert every pending save into one staged CAS manifest. Default
--- behavior returns caller instructions. `execute=true` runs the same
--- push/fetch explicitly; there is still no implicit network path.
--- @param s store.Store The store
--- @return boolean True once every pending ref landed (or there was
--- nothing to push)
--- @return string Error message; `LOST_RACE` exactly, for a lost race
local function publish(s: store.Store, execute?: boolean): boolean, string
  local remote = refs.board_remote(s.root)
  if #s.pending == 0 then
    s.pending = {}
    return true
  end

  -- `gitwrite` has just created the successor commits and temporarily
  -- moved their local target refs. Capture the successors, commit the
  -- Git-native CAS manifest, then put a remote-backed checkout's
  -- local heads back exactly where they were. From that point onward
  -- the manifest is the only reachable local publication plan and
  -- fetched remote-tracking refs are the only confirmed state.
  local updates: {prepared.Update} = {}
  local resets: {refs.RefUpdate} = {}
  for _, p in ipairs(s.pending) do
    local next_sha, nerr = refs.read_ref(s.root, p.ref)
    if next_sha == nil or next_sha == refs.ZERO_SHA then
      return false, nerr ~= "" and nerr or "prepared successor ref disappeared"
    end
    local expected = p.old
    if expected == "" then
      expected = refs.ZERO_SHA
    end
    updates[#updates + 1] = {ref = p.ref, expected = expected, next = next_sha}
    -- A remote-backed board never reads local target heads as
    -- canonical, so remove the temporary fast-import ref altogether.
    resets[#resets + 1] = {ref = p.ref, expected = next_sha,
      next = refs.ZERO_SHA}
  end
  local tx, terr = prepared.prepare(s.root, updates)
  if tx == nil then
    return false, terr
  end
  if refs.board_mode(s.root) == "local" then
    -- The local fast-import already performed the CAS. Refresh sees
    -- those local heads as canonical and cleans the manifest.
    s.pending = {}
    local confirmed, cerr = prepared.refresh(s.root, remote)
    if confirmed == nil then
      return false, cerr
    end
    return true, ""
  end

  local reset, rerr = refs.update_refs_atomic(s.root, resets)
  if not reset then
    return false, ("prepared %s, but could not restore local heads: %s")
    :format(tx.staging_ref, rerr)
  end
  s.pending, s.leased_ref, s.leased_sha, s.leased_item, s.touched_at = {}, {}, {}, {}, {}
  s.observed_seq = ""
  local _cok, _cerr = store.close(s)

  local push = prepared.push_argv(tx, remote)
  local fetch = prepared.fetch_argv(remote)
  if not execute then
    return true, ("prepared %s\npublish: %s\nrefresh refs: %s")
    :format(tx.staging_ref, table.concat(push, " "), table.concat(fetch, " "))
  end
  local pushed, perr = prepared.execute(s.root, push)
  if not pushed then
    -- A failed explicit push never replays the mutation. It remains
    -- staged with its original leases for retry or diagnosis.
    return false, perr
  end
  local fetched, ferr = prepared.execute(s.root, fetch)
  if not fetched then
    return false, ("published, but refresh fetch failed: %s"):format(ferr)
  end
  local outcomes, oerr = prepared.refresh(s.root, remote)
  if outcomes == nil then
    return false, oerr
  end
  for _, outcome in ipairs(outcomes) do
    if outcome.transaction.staging_ref == tx.staging_ref
    and outcome.state ~= "confirmed" then
      return false, outcome.detail
    end
  end
  return true, ""
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
  sync: function(s: store.Store, execute?: boolean): boolean, string
  publish: function(s: store.Store, execute?: boolean): boolean, string
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
