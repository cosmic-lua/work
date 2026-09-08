--- Read-only compatibility for the retired provider CI cache.
---
--- v3 board semantics record commit ids only. Gitboard never discovers a
--- provider, reads credentials, observes checks, or refreshes this cache.
--- Callers inspect checks using their own authenticated tooling against the
--- exact handover/verdict SHA. The row readers remain temporarily so an old
--- disposable cache can be inspected while clients migrate; no production
--- path writes or trusts those rows.
local cachedb = require("_work.cachedb")
local env = require("cosmic.env")
local freshness = require("_work.freshness")
local item = require("_work.item")
local store = require("_work.store")

local FRESH_ENV < const > = "GITBOARD_CI_FRESH"
local RECENT_PUSH_S < const > = 20 * 60
local DISABLED < const > = "provider CI observation is disabled — inspect checks "
.. "with caller-owned tooling on the recorded commit id"

local record ciobs
  record Run
    name: string
    status: string
    conclusion: string
  end
  record Observation
    state: string
    head_sha: string
    runs: {Run}
  end
  FRESH_ENV: string
  RECENT_PUSH_S: integer
  DISABLED: string
  read: function(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  head_of: function(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  fresh: function(age_s: integer): boolean
  current_state: function(c: cachedb.Cache, repo: string, pr: integer, id: string):
  string | nil
  record: function(c: cachedb.Cache, repo: string, pr: integer,
  observation: any): boolean, string
  observe: function(s: store.Store, c: cachedb.Cache, repo: string, pr: integer):
  string | nil, string
  live: function(s: store.Store, repo: string, pr: integer): Observation | nil, string
  is_candidate: function(it: item.Item, stage_by_id: {string: integer}): boolean
  at_sync: function(s: store.Store): {string}
end

local function read(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  local row = c.db:query_one(
    "SELECT state, observed_at FROM ci_checks WHERE repo = ? AND pr = ?",
    {repo, pr})
  if row == nil then return nil, 0 end
  local observed_at = math.tointeger(row.observed_at as number) or 0 -- cast: sqlite row
  return row.state as string, os.time() - observed_at -- cast: sqlite row
end

local function head_of(c: cachedb.Cache, repo: string, pr: integer): string | nil, integer
  local row = c.db:query_one(
    "SELECT head, observed_at FROM ci_checks WHERE repo = ? AND pr = ?",
    {repo, pr})
  if row == nil then return nil, 0 end
  local observed_at = math.tointeger(row.observed_at as number) or 0 -- cast: sqlite row
  return row.head as string, os.time() - observed_at -- cast: sqlite row
end

local function fresh(age_s: integer): boolean
  return (env.get(FRESH_ENV) or "") == "" and age_s < freshness.WINDOW_S
end

local function current_state(_c: cachedb.Cache, _repo: string, _pr: integer,
    _id: string): string | nil
  return nil
end

--- Compatibility writer for migration tests only. Core v3 code never calls it.
local function record_row(c: cachedb.Cache, repo: string, pr: integer,
    observation: any): boolean, string
  local fields = observation as {string: any} -- cast: legacy compatibility input
  local head = fields["head_sha"] as string -- cast: legacy observation shape
  local state = fields["state"] as string -- cast: legacy observation shape
  return c.db:exec([[
    INSERT INTO ci_checks(repo, pr, head, state, observed_at) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(repo, pr) DO UPDATE SET head = excluded.head,
      state = excluded.state, observed_at = excluded.observed_at
  ]], {repo, pr, head, state, os.time()})
end

local function observe(_s: store.Store, _c: cachedb.Cache, _repo: string,
    _pr: integer): string | nil, string
  return nil, DISABLED
end

local function live(_s: store.Store, _repo: string, _pr: integer):
  ciobs.Observation | nil, string
  return nil, DISABLED
end

local function is_candidate(_it: item.Item,
    _stage_by_id: {string: integer}): boolean
  return false
end

local function at_sync(_s: store.Store): {string}
  return {}
end

local M: ciobs = {
  FRESH_ENV = FRESH_ENV,
  RECENT_PUSH_S = RECENT_PUSH_S,
  DISABLED = DISABLED,
  read = read,
  head_of = head_of,
  fresh = fresh,
  current_state = current_state,
  record = record_row,
  observe = observe,
  live = live,
  is_candidate = is_candidate,
  at_sync = at_sync,
}

return M
