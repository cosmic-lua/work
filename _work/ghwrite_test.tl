#!/usr/bin/env cosmic
-- The GitHub writes a verdict performs: each wrapper's request shape,
-- proven against `_work.api`'s transport seam rather than a real
-- GitHub write — the same posture `gh_test.tl` takes with `open_pull`.

local env = require("cosmic.env")
local fetch = require("cosmic.fetch")
local json = require("cosmic.json")

local api = require("_work.api")
local ghwrite = require("_work.ghwrite")

--- Point `GITHUB_TOKEN` at a fake value for the duration of a test —
--- `api.call` refuses to run with none set, and these tests never
--- spend a real one. Returns what to restore.
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

-- `merge_pull` PUTs the squash-merge request with the judged head's
-- sha, so a head that moved since the review is a refused merge, not
-- a merge of unreviewed code, and reports the merge commit sha back.
local function test_merge_pull_puts_the_expected_request()
  local seen: fetch.Options = nil
  local seen_url = ""
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    seen_url, seen = url, opts
    return {status = 200, headers = {}, raw_headers = {},
      body = '{"sha":"deadbeef","merged":true}', url = url}
    as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, sha = ghwrite.merge_pull({root = ""}, "acme/widgets", 7, "abcd1234")
  api.transport = original
  restore_token(prior)
  assert(ok, "got: " .. tostring(sha))
  assert(sha == "deadbeef", "got: " .. tostring(sha))
  assert(seen.method == "PUT", tostring(seen.method))
  assert(seen_url:find("/repos/acme/widgets/pulls/7/merge", 1, true) ~= nil, seen_url)
  local decoded = json.decode(seen.body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(decoded["merge_method"] == "squash" and decoded["sha"] == "abcd1234",
    "the payload names the squash method and the judged head")
end

-- A 409 (the head moved, or a merge queue holds it) is a failure
-- whose message carries the status, so a caller can match "HTTP 409"
-- to decide on the auto-merge fallback rather than guessing.
local function test_merge_pull_409_is_a_failure_naming_the_status()
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, _opts: fetch.Options): fetch.Response | nil, fetch.Error
    return {status = 409, headers = {}, raw_headers = {},
      body = '{"message":"Head branch was modified"}', url = url}
    as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, msg = ghwrite.merge_pull({root = ""}, "acme/widgets", 7, "abcd1234")
  api.transport = original
  restore_token(prior)
  assert(not ok, "a 409 is not a success")
  assert(msg:find("HTTP 409", 1, true) ~= nil, "got: " .. msg)
end

-- `enable_auto_merge` POSTs a GraphQL mutation naming the PR's node id
-- and the squash method, and succeeds on the 200 GraphQL always
-- answers with when the mutation itself went through.
local function test_enable_auto_merge_posts_the_expected_mutation()
  local seen: fetch.Options = nil
  local seen_url = ""
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    seen_url, seen = url, opts
    return {status = 200, headers = {}, raw_headers = {},
      body = '{"data":{"enablePullRequestAutoMerge":{"clientMutationId":null}}}',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, err = ghwrite.enable_auto_merge({root = ""}, "PR_kwABC")
  api.transport = original
  restore_token(prior)
  assert(ok, "got: " .. tostring(err))
  assert(seen.method == "POST", tostring(seen.method))
  assert(seen_url:find("/graphql", 1, true) ~= nil, seen_url)
  local decoded = json.decode(seen.body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(tostring(decoded["query"]):find("enablePullRequestAutoMerge", 1, true) ~= nil,
    "the query names the mutation")
  assert(tostring(decoded["query"]):find("SQUASH", 1, true) ~= nil,
    "the query names the squash method")
  local variables = decoded["variables"] as {string: any} -- cast: a decoded JSON object, known by construction
  assert(variables["id"] == "PR_kwABC", "the node id rides as a variable")
end

-- GraphQL answers 200 even on a mutation failure, naming it in an
-- `errors` array rather than the HTTP status — a caller that only
-- read the status would wrongly call this a success.
local function test_enable_auto_merge_reports_a_graphql_error()
  local original = api.transport
  local prior = stub_token()
  api.transport = function(_url: string, _opts: fetch.Options): fetch.Response | nil, fetch.Error
    return {status = 200, headers = {}, raw_headers = {},
      body = '{"errors":[{"message":"Pull request is in clean status"}]}',
      url = _url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, err = ghwrite.enable_auto_merge({root = ""}, "PR_kwABC")
  api.transport = original
  restore_token(prior)
  assert(not ok, "a GraphQL errors array is a failure")
  assert(err:find("Pull request is in clean status", 1, true) ~= nil,
    "got: " .. err)
end

-- `post_review` POSTs a formal REQUEST_CHANGES review pinned to the
-- judged head, carrying the caller's body verbatim.
local function test_post_review_posts_the_expected_request()
  local seen: fetch.Options = nil
  local seen_url = ""
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    seen_url, seen = url, opts
    return {status = 200, headers = {}, raw_headers = {}, body = '{"id":1}',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, err = ghwrite.post_review({root = ""}, "acme/widgets", 7,
    "abcd1234", "the concrete gaps")
  api.transport = original
  restore_token(prior)
  assert(ok, "got: " .. tostring(err))
  assert(seen.method == "POST", tostring(seen.method))
  assert(seen_url:find("/repos/acme/widgets/pulls/7/reviews", 1, true) ~= nil,
    seen_url)
  local decoded = json.decode(seen.body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(decoded["event"] == "REQUEST_CHANGES"
    and decoded["commit_id"] == "abcd1234"
    and decoded["body"] == "the concrete gaps",
    "the payload carries the formal review's own fields")
end

-- `close_pull` PATCHes the request closed.
local function test_close_pull_patches_the_expected_request()
  local seen: fetch.Options = nil
  local seen_url = ""
  local original = api.transport
  local prior = stub_token()
  api.transport = function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    seen_url, seen = url, opts
    return {status = 200, headers = {}, raw_headers = {}, body = '{"state":"closed"}',
      url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
  local ok, err = ghwrite.close_pull({root = ""}, "acme/widgets", 7)
  api.transport = original
  restore_token(prior)
  assert(ok, "got: " .. tostring(err))
  assert(seen.method == "PATCH", tostring(seen.method))
  assert(seen_url:find("/repos/acme/widgets/pulls/7", 1, true) ~= nil, seen_url)
  local decoded = json.decode(seen.body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(decoded["state"] == "closed", "the payload closes the request")
end
