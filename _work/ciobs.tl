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
--- window, and a hot loop pays nothing. The verbs that DECIDE on CI
--- (`take --pr`, `verdict`, `done`, `_work/gitverbs.tl`) never touch
--- this cache; they keep the live read they always made, because a
--- decision needs the current word, not a recent one.
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
  local ok, werr = c.db:exec([[
    INSERT INTO ci_checks(repo, pr, head, state, observed_at) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(repo, pr) DO UPDATE SET head = excluded.head,
      state = excluded.state, observed_at = excluded.observed_at
  ]], {repo, pr, hc.head_sha, hc.state, os.time()})
  if not ok then
    return nil, werr
  end
  return hc.state, ""
end

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

local record ciobs
  FRESH_ENV: string
  read: function(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  fresh: function(age_s: integer): boolean
  observe: function(s: store.Store, c: cachedb.Cache, repo: string, pr: integer):
  string | nil, string
  is_candidate: function(it: item.Item): boolean
  at_sync: function(s: store.Store): {string}
end

local M: ciobs = {
  FRESH_ENV = FRESH_ENV,
  read = read,
  fresh = fresh,
  observe = observe,
  is_candidate = is_candidate,
  at_sync = at_sync,
}

return M
