#!/usr/bin/env cosmic
-- The addressing half of the GitHub reads: which `owner/repo` a call
-- goes to, decided from the item's field or the checkout's origin.
-- That decision runs with no network and no token; the reads
-- themselves (`pull`, `checks`) need both, and are exercised only
-- through the board's own flow against a real repository. `open_pull`
-- is the one write: `_work.api`'s `M.transport` seam stands in for
-- the live network here, so its request shape and idempotent 422
-- fallback are proven without spending a real GitHub write.

local env = require("cosmic.env")
local fetch = require("cosmic.fetch")
local json = require("cosmic.json")

local api = require("_work.api")
local gh = require("_work.gh")
local fixture = require("_work.fixture")

--- Point `GITHUB_TOKEN` at a fake value for the duration of an
--- `open_pull` test — `api.call` refuses to run with none set, and
--- these tests never spend a real one. Returns what to restore.
--- @return string | nil The prior value, nil when unset
local function stub_token(): string | nil
  local prior = env.get("GITHUB_TOKEN")
  assert(env.set("GITHUB_TOKEN", "test-token"))
  return prior
end

--- Restore `GITHUB_TOKEN` to what `stub_token` found.
--- @param prior string | nil What `stub_token` returned
local function restore_token(prior: string | nil)
  if prior == nil then
    local _ok, _err = env.unset("GITHUB_TOKEN")
  else
    assert(env.set("GITHUB_TOKEN", prior))
  end
end

-- `open_pull` POSTs the request GitHub's "create a pull request"
-- endpoint expects, with the item's own fields as the JSON body, and
-- decodes the number a successful response carries.
local function test_open_pull_posts_the_expected_request()
  local seen: fetch.Options = nil
  local seen_url = ""
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    seen_url, seen = url, opts
    return {status = 201, headers = {}, raw_headers = {}, body = '{"number":42}',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local number, err = gh.open_pull({root = ""}, "acme/widgets", "abcd1234",
    "main", "a title", "a body")
  api.transport = original
  restore_token(prior)
  assert(number == 42, "got: " .. tostring(number) .. " " .. tostring(err))
  assert(seen.method == "POST", tostring(seen.method))
  assert(seen_url:find("/repos/acme/widgets/pulls", 1, true) ~= nil, seen_url)
  assert(seen.headers["content-type"] == "application/json",
    "a body request carries content-type")
  local decoded = json.decode(seen.body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(decoded["head"] == "abcd1234" and decoded["base"] == "main"
    and decoded["title"] == "a title" and decoded["body"] == "a body"
    and decoded["draft"] == false, "the payload carries the item's own fields")
end

-- A 422 saying the head already carries an open PR is not a failure:
-- a retried --open looks the existing number up and hands it back
-- rather than surfacing GitHub's refusal, so it never opens a second
-- PR for the same head.
local function test_open_pull_422_already_exists_finds_the_number()
  local posts = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    if opts.method == "POST" then
      posts = posts + 1
      return {status = 422, headers = {}, raw_headers = {},
        body = '{"message":"Validation Failed","errors":'
        .. '[{"message":"A pull request already exists for acme:abcd1234."}]}',
        url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end
    return {status = 200, headers = {}, raw_headers = {}, body = '[{"number":99}]',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local number, err = gh.open_pull({root = ""}, "acme/widgets", "abcd1234",
    "main", "a title", "a body")
  api.transport = original
  restore_token(prior)
  assert(number == 99, "got: " .. tostring(number) .. " " .. tostring(err))
  assert(posts == 1, "one POST, never retried into a second PR")
end

-- A 422 for an unrelated validation failure is a real failure: nothing
-- here guesses that a random rejection means "already open."
local function test_open_pull_422_for_another_reason_is_a_failure()
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, _opts: fetch.Options): fetch.Response | nil, fetch.Error
    return {status = 422, headers = {}, raw_headers = {},
      body = '{"message":"Validation Failed","errors":'
      .. '[{"message":"head is not a valid ref"}]}',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local number, err = gh.open_pull({root = ""}, "acme/widgets", "abcd1234",
    "main", "a title", "a body")
  api.transport = original
  restore_token(prior)
  assert(number == nil, "an unrelated 422 is not idempotency")
  assert(err:find("422", 1, true) ~= nil, err)
end

-- A non-empty repo short-circuits before touching git — no store root
-- is ever read, so a bogus one proves the short-circuit rather than
-- masking a git call that happened to succeed.
local function test_slug_short_circuits_on_a_set_repo()
  local slug = gh.slug({root = "/does/not/exist"}, "whilp/cosmopolitan")
  assert(slug == "whilp/cosmopolitan", "got: " .. tostring(slug))
end

-- With no repo field the slug comes from origin, so a checkout that
-- has no origin can address nothing: that is a named error, not a
-- guess at a default repository.
local function test_slug_without_an_origin_is_an_error()
  local s = fixture.init_state_repo("gh-slug")
  local slug, err = gh.slug(s, "")
  assert(slug == nil, "a checkout with no origin addresses nothing")
  assert(err:find("no origin remote", 1, true) ~= nil, "got: " .. err)
end

-- `head_state` is the pure classification `head_checks` composes with
-- a fetched pull and its check runs — exercised directly against
-- synthetic run lists, the same way `review_test.tl` exercises
-- `blocks_on_ci` directly, rather than only through a stub standing
-- in for the whole of `head_checks`.
local function test_head_state_is_green_when_every_run_completed_clean()
  assert(gh.head_state({
        {name = "ci", status = "completed", conclusion = "success"},
      }) == "green", "one clean completed run is green")
end

local function test_head_state_is_red_on_a_concluded_failure()
  assert(gh.head_state({
        {name = "ci", status = "completed", conclusion = "success"},
        {name = "build", status = "completed", conclusion = "failure"},
      }) == "red", "a concluded failure among the runs is red")
end

local function test_head_state_is_running_while_anything_is_incomplete()
  assert(gh.head_state({
        {name = "ci", status = "completed", conclusion = "success"},
        {name = "smoke", status = "in_progress", conclusion = ""},
      }) == "running", "one run still going, none failed yet, is running")
end

local function test_head_state_is_none_with_no_runs_at_all()
  assert(gh.head_state({}) == "none", "an empty run list is none")
end

-- `latest_request_changes` is the pure selection `bounce_context`
-- composes with a fetched review list — exercised directly against a
-- synthetic list, the same way `head_state`'s siblings above exercise
-- that classification directly rather than only through a stub
-- standing in for the whole of a live read.
local function test_latest_request_changes_picks_the_most_recent_by_submitted_at()
  local finding = gh.latest_request_changes({
      {state = "CHANGES_REQUESTED", body = "an older, already-fixed complaint",
        submitted_at = "2024-01-01T00:00:00Z"},
      {state = "APPROVED", body = "looks fine now",
        submitted_at = "2024-01-03T00:00:00Z"},
      {state = "CHANGES_REQUESTED", body = "the real, current finding",
        submitted_at = "2024-01-02T00:00:00Z"},
    })
  assert(finding ~= nil and finding.body == "the real, current finding",
    "the most recent CHANGES_REQUESTED review wins, by submitted_at "
    .. "not list order")
end

local function test_latest_request_changes_is_nil_with_no_matching_review()
  local finding = gh.latest_request_changes({
      {state = "APPROVED", body = "lgtm", submitted_at = "2024-01-01T00:00:00Z"},
      {state = "COMMENTED", body = "a passing remark",
        submitted_at = "2024-01-02T00:00:00Z"},
    })
  assert(finding == nil, "no CHANGES_REQUESTED review at all is nil, not a guess")
end

local function test_latest_request_changes_matches_a_marked_own_pr_comment()
  local finding = gh.latest_request_changes({
      {state = "COMMENTED", body = "request-changes:\nthe finding, on line two",
        submitted_at = "2024-01-01T00:00:00Z"},
      {state = "COMMENTED", body = "reject:", submitted_at = "2024-01-02T00:00:00Z"},
    })
  assert(finding ~= nil and finding.body == "reject:",
    "a COMMENTED review whose FIRST line is the own-PR marker is a bounce, "
    .. "and the most recent one wins")
end

local function test_latest_request_changes_ignores_a_marker_below_the_first_line()
  local finding = gh.latest_request_changes({
      {state = "COMMENTED", body = "nit: the message mentions reject: in prose",
        submitted_at = "2024-01-01T00:00:00Z"},
      {state = "COMMENTED", body = "lgtm\nrequest-changes:",
        submitted_at = "2024-01-02T00:00:00Z"},
      {state = "COMMENTED", body = " request-changes:",
        submitted_at = "2024-01-03T00:00:00Z"},
    })
  assert(finding == nil, "the marker counts only as the exact, whole first line — "
    .. "a mention later in the body, or on a later line, is a plain comment")
end
