--- A pull request's CI state as a board OBSERVATION rather than a
--- live read every render pays for. `_work.gh.head_checks` stays the
--- one place that actually reaches GitHub; this module caches its
--- result in the cache database's `ci_checks` table, one row per
--- `(repo, pr)`, and decides how long a row stays trusted before a
--- caller is willing to spend another round trip on it — the same
--- freshness-window shape `_work.lanes` already uses for scheduled-lane
--- health, sharing its window (`_work.freshness`) rather than picking
--- a second one.
---
--- `_work/gitview.tl`'s `ci_states` is the one render-side caller: read
--- first, observe only when the row is absent or has aged past the
--- window — so a render pays the network at most once per item per
--- window, and a hot loop pays nothing. A render cannot learn the
--- CURRENT head without a live call — the very thing the window
--- exists to bound — so a push is NOT detected until the row's own
--- age forces a refresh: a row may lag a real push by up to the
--- window. `live` closes most of that gap from the other end: the
--- deciding verbs (`take --pr`, `_work/gitverbs.tl`) already make
--- their own live read to decide, and `live` writes that result
--- through to the cache as a side effect, so the row is fresh again
--- the moment the flow itself learns of a new head — `verdict` and
--- `done` read the PR directly (`gh.pull`), never `head_checks`, so
--- they have nothing to write through here.
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local env = require("cosmic.env")
local flow = require("_work.flow")
local freshness = require("_work.freshness")
local gh = require("_work.gh")
local item = require("_work.item")
local store = require("_work.store")

--- Set (to anything) to force a read past the freshness window — the
--- CI counterpart to `_work.lanes.FRESH_ENV`.
local FRESH_ENV < const > = "GITBOARD_CI_FRESH"

--- The last-observed state for one pull request, read from the cache's
--- `ci_checks` table — no GitHub reach at all. `repo` is whatever the
--- item's own `repo` field holds, "" included: the row is scoped to
--- THIS checkout, where "" always resolves to the same origin, so it
--- is a stable cache key even though it is not a real slug.
--- @param c cachedb.Cache An open cache connection
--- @param repo string The item's repo field, "" when unset
--- @param pr integer The PR number
--- @return string | nil The last-observed state; nil when never observed
--- @return integer Seconds since it was observed; 0 when never observed
local function read(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  local row = c.db:query_one(
    "SELECT state, observed_at FROM ci_checks WHERE repo = ? AND pr = ?",
    {repo, pr})
  if row == nil then
    return nil, 0
  end
  local observed_at = math.tointeger(row.observed_at as number) or 0 -- cast: from any (sqlite row)
  return row.state as string, os.time() - observed_at -- cast: from any (sqlite row)
end

--- Whether an observation this many seconds old is still trusted:
--- purely the shared window, unless `GITBOARD_CI_FRESH` forces past
--- it — the same override shape `_work.lanes.FRESH_ENV` gives lane
--- health.
--- @param age_s integer Seconds since the observation was made
--- @return boolean True when still fresh enough to reuse
local function fresh(age_s: integer): boolean
  if (env.get(FRESH_ENV) or "") ~= "" then
    return false
  end
  return age_s < freshness.WINDOW_S
end

--- Upsert an already-fetched `HeadChecks` into the row — the write
--- half of `observe`, exposed on its own so `live` (and any other
--- caller that already paid for a `head_checks` call for its own
--- reasons) can keep the cache fresh without a second round trip.
--- @param c cachedb.Cache An open cache connection
--- @param repo string The item's repo field, "" when unset
--- @param pr integer The PR number
--- @param hc gh.HeadChecks The already-fetched result
--- @return boolean True on success
--- @return string Error message
local function record_row(c: cachedb.Cache, repo: string, pr: integer,
    hc: gh.HeadChecks): boolean, string
  return c.db:exec([[
    INSERT INTO ci_checks(repo, pr, head, state, observed_at) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(repo, pr) DO UPDATE SET head = excluded.head,
      state = excluded.state, observed_at = excluded.observed_at
  ]], {repo, pr, hc.head_sha, hc.state, os.time()})
end

local record ciobs
  FRESH_ENV: string
  read: function(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  fresh: function(age_s: integer): boolean
  record: function(c: cachedb.Cache, repo: string, pr: integer, hc: gh.HeadChecks):
  boolean, string
  observe: function(s: store.Store, c: cachedb.Cache, repo: string, pr: integer):
  string | nil, string
  live: function(s: store.Store, repo: string, pr: integer): gh.HeadChecks | nil, string
  is_candidate: function(it: item.Item): boolean
  at_sync: function(s: store.Store): {string}
end

-- `record` is also a Teal keyword — only a call through the qualified
-- `M.record` parses as one, so every caller here reaches the write
-- half through `M` rather than the bare local, the same workaround
-- `_work/lanes.tl`'s `report` uses for its own `M.record`.
local M: ciobs = {
  FRESH_ENV = FRESH_ENV,
  read = read,
  fresh = fresh,
  record = record_row,
}

--- Read the pull request's checks live and upsert the row — the one
--- live call `read` plus `fresh` allow at most once per item per
--- window. Failure (no origin, no token, a network error) leaves
--- whatever was cached untouched and reports the same way
--- `_work.gh.head_checks` always did: nil is "unknown", never "red".
--- @param s store.Store The store
--- @param c cachedb.Cache An open cache connection
--- @param repo string The item's repo field, "" when unset
--- @param pr integer The PR number
--- @return string | nil The freshly observed state
--- @return string Error message
local function observe(s: store.Store, c: cachedb.Cache, repo: string,
    pr: integer): string | nil, string
  local hc, err = gh.head_checks(s, pr, repo)
  if hc == nil then
    return nil, err
  end
  local ok, werr = M.record(c, repo, pr, hc)
  if not ok then
    return nil, werr
  end
  return hc.state, ""
end

M.observe = observe

--- The deciding verbs' own live read, writing through to the cache as
--- a side effect: opens a connection itself (there is no already-open
--- one at a decision site), records the result when the cache opens,
--- and returns the SAME `gh.HeadChecks` a bare `gh.head_checks` call
--- would — a decision reads the whole record (the sha, the run list),
--- never only the state `observe`'s render path narrows to. A cache
--- that will not even open is not this call's problem to fail over:
--- the live result still returns exactly as it always did.
--- @param s store.Store The store
--- @param repo string The item's repo field, "" when unset
--- @param pr integer The PR number
--- @return gh.HeadChecks | nil The live result
--- @return string Error message
local function live(s: store.Store, repo: string, pr: integer): gh.HeadChecks | nil, string
  local hc, err = gh.head_checks(s, pr, repo)
  if hc == nil then
    return nil, err
  end
  local c, _cerr = cache.open(s.root)
  if c ~= nil then
    local _ok, _werr = M.record(c, repo, pr, hc)
    local _cok, _ccerr = cache.close(c)
  end
  return hc, ""
end

M.live = live

--- Whether `it` is a candidate this module observes at all: an open
--- review-stage item carrying a PR — the exact test `_work/gitview.tl`'s
--- `ci_states` runs per item, restated here so `at_sync` walks the
--- same set without needing that module's help.
--- @param it item.Item The item
--- @return boolean True when `it` is a CI-observation candidate
local function is_candidate(it: item.Item): boolean
  return item.is_open(it) and flow.stage_rank(it) == flow.STAGE_REVIEW
  and (it.pr or 0) ~= 0
end

M.is_candidate = is_candidate

--- Refresh every open review-stage item's observation that has aged
--- past the window, the way `_work.lanes.at_sync` refreshes lane
--- health — so a loop that syncs first never blocks `next` on GitHub
--- at all. Silent when nothing needed refreshing or every refresh
--- succeeded; an `observe` failure is reported the same way `_work.lanes`
--- reports one, rather than left to vanish. A cache or board read that
--- cannot even open is reported too, never silently skipped.
--- @param s store.Store The store
--- @return {string} Lines for the caller to print, one per failure
local function at_sync(s: store.Store): {string}
  local all, aerr = store.list(s)
  if all == nil then
    return {("gitboard-sync: ci: %s"):format(aerr)}
  end
  local c, cerr = cache.open(s.root)
  if c == nil then
    return {("gitboard-sync: ci: %s"):format(cerr)}
  end
  local lines: {string} = {}
  for _, it in ipairs(all) do
    if is_candidate(it) then
      local cached, age = read(c, it.repo, it.pr)
      if cached == nil or not fresh(age) then
        local state, oerr = observe(s, c, it.repo, it.pr)
        if state == nil then
          lines[#lines + 1] = ("gitboard-sync: ci %s pr %d: %s")
          :format(it.id:sub(1, 8), it.pr, oerr)
        end
      end
    end
  end
  local _ok, _cerr = cache.close(c)
  return lines
end

M.at_sync = at_sync

return M
