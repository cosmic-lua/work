#!/usr/bin/env cosmic
-- `verdict` against a real PR performs the GitHub side itself: an
-- accept lands the PR (merge, falling back to auto-merge on a
-- refused direct merge), and a request-changes or reject posts the
-- formal review `--body FILE` carries. Split out of `gitverdict_test.tl`
-- to keep it under the file cap — these are the only cases that stub
-- a live PR through `_work.api`'s transport seam; everything else
-- there runs against a local-only fixture board with no origin.

local check = require("cosmic.check")
local env = require("cosmic.env")
local fetch = require("cosmic.fetch")
local fs = require("cosmic.fs")
local json = require("cosmic.json")

local api = require("_work.api")
local fixture = require("_work.fixture")
local store = require("_work.store")
local verbs = require("_work.gitverbs")
local vrd = require("_work.gitverdict")

local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

local HEAD < const > = "cafe1234000000000000000000000000000000"

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

--- A store whose origin reads as `acme/widgets` on GitHub, with one
--- claimed leaf, not yet handed over — the caller stubs the transport
--- (the leaf's own id must ride the fake PR's `Board:` line) before
--- handing it over with a real `--pr`, since `take` reads the PR too.
--- @param name string A unique fixture name
--- @return store.Store The store
--- @return string The leaf's id
local function claimed_leaf(name: string): store.Store, string
  local s = fixture.init_shared(name)
  fixture.github_origin(s, "acme/widgets")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  return s, leaf
end

--- The fake pull payload `merge`/`checks` calls read: open, not a
--- draft, joined to `leaf` by its `Board:` line, mergeable, and
--- carrying a GraphQL node id — deviations are built by copying
--- `fields` over these defaults.
--- @param leaf string The item id the PR's body names
--- @param fields {string: any} Overrides
--- @return string The JSON body
local function pull_body(leaf: string, fields: {string: any}): string
  local base: {string: any} = {
    number = 55, draft = false, merged = false, body = "Board: " .. leaf,
    head = {sha = HEAD}, base = {ref = "main"}, state = "open",
    merge_commit_sha = "", mergeable_state = "clean", node_id = "PR_kwXYZ",
  }
  for k, v in pairs(fields) do
    base[k] = v
  end
  return check.must(json.encode(base))
end

--- A transport fake that answers every GET — the PR itself and its
--- check-runs — with a mergeable, CI-silent request joined to `leaf`,
--- and routes anything else (the one write each test cares about) to
--- `on_write`.
--- @param leaf string The item id the PR's body names
--- @param fields {string: any} Overrides for the pull payload
--- @param on_write function(string, fetch.Options): fetch.Response | nil, fetch.Error
--- @return function(string, fetch.Options): fetch.Response | nil, fetch.Error
local function fake_transport(leaf: string, fields: {string: any},
    on_write: function(string, fetch.Options): fetch.Response | nil, fetch.Error):
  function(string, fetch.Options): fetch.Response | nil, fetch.Error
  return function(url: string, opts: fetch.Options): fetch.Response | nil, fetch.Error
    if opts.method == "GET" then
      if url:find("/check-runs", 1, true) ~= nil then
        return {status = 200, headers = {}, raw_headers = {},
          body = '{"check_runs":[]}', url = url}
        as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
      end
      return {status = 200, headers = {}, raw_headers = {},
        body = pull_body(leaf, fields), url = url}
      as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end
    return on_write(url, opts)
  end
end

--- Run `vrd.cmd_verdict` and capture exactly what it prints via
--- `print()` — the same swap-and-restore pattern `gitverdict_test.tl`'s
--- own `verdict_and_capture` uses.
--- @param s store.Store The store
--- @param id string The item under verdict
--- @param kind string accept | request changes | reject
--- @param pr integer The PR the verdict judges
--- @param head string The head commit the verdict judges
--- @param session string | nil The reviewing session
--- @param body_file string | nil The `--body` file, "" for none
--- @param no_land boolean | nil `--no-land`
--- @return integer cmd_verdict's exit code
--- @return string Every print()'d line, newline-joined
local function verdict_and_capture(s: store.Store, id: string, kind: string,
    pr: integer, head: string, session?: string, body_file?: string,
    no_land?: boolean): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(vrd.cmd_verdict, s, id, kind, pr, head, session,
    false, "", body_file, no_land)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- A mergeable PR is landed directly: `verdict accept` PUTs the merge,
-- and the item ends here — the same run as an already-merged accept,
-- because the landing this accept authorises just happened.
local function test_accept_lands_a_mergeable_pr()
  local s, leaf = claimed_leaf("land-merge")
  local puts = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(url: string,
        _opts: fetch.Options): fetch.Response | nil, fetch.Error
      puts = puts + 1
      assert(url:find("/repos/acme/widgets/pulls/61/merge", 1, true) ~= nil, url)
      return {status = 200, headers = {}, raw_headers = {},
        body = '{"sha":"deadbeef","merged":true}', url = url}
      as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 61, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 61, "cafe1234",
    "reviewer-a")
  api.transport = original
  restore_token(prior)
  assert(code == 0, "got: " .. tostring(printed))
  assert(puts == 1, "one merge PUT")
  local it = check.must(store.load(s, leaf))
  assert(it.resolution == "completed", "the item ends here, landed itself")
  assert(it.claim == "", "the claim clears with the completion")
end

-- A 409 (a merge queue, or the head moved under GitHub's own check)
-- falls back to arming auto-merge through the GraphQL mutation rather
-- than failing the verdict outright; the accept still stands, awaiting
-- the merge GitHub will complete on its own.
local function test_accept_falls_back_to_auto_merge_on_409()
  local s, leaf = claimed_leaf("land-fallback")
  local mutations = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(url: string,
        opts: fetch.Options): fetch.Response | nil, fetch.Error
      if opts.method == "PUT" then
        return {status = 409, headers = {}, raw_headers = {},
          body = '{"message":"Head branch was modified"}', url = url}
        as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
      end
      mutations = mutations + 1
      assert(url:find("/graphql", 1, true) ~= nil, url)
      local decoded = json.decode(opts.body) as {string: any} -- cast: a decoded JSON object, known by construction
      local variables = decoded["variables"] as {string: any} -- cast: a decoded JSON object, known by construction
      assert(variables["id"] == "PR_kwXYZ", "the mutation names the PR's node id")
      return {status = 200, headers = {}, raw_headers = {},
        body = '{"data":{"enablePullRequestAutoMerge":{"clientMutationId":null}}}',
        url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 62, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 62, "cafe1234",
    "reviewer-a")
  api.transport = original
  restore_token(prior)
  assert(code == 0, "got: " .. tostring(printed))
  assert(mutations == 1, "one auto-merge mutation")
  local it = check.must(store.load(s, leaf))
  assert(it.resolution == "", "not landed yet — GitHub completes it")
  assert(it.verdict == "accept", "the accept stands, awaiting the merge")
end

-- A 409 falls back to the GraphQL mutation, and the environment's own
-- proxy can refuse THAT too (only a pinned set of GraphQL operations
-- served) — the verdict is still recorded, exactly as `--no-land`
-- would leave it, and the refusal rides the line instead of the whole
-- verb: nothing is lost, and a human lands it by hand.
local function test_accept_records_when_auto_merge_is_refused()
  local s, leaf = claimed_leaf("land-graphql-403")
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(url: string,
        opts: fetch.Options): fetch.Response | nil, fetch.Error
      if opts.method == "PUT" then
        return {status = 409, headers = {}, raw_headers = {},
          body = '{"message":"Head branch was modified"}', url = url}
        as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
      end
      assert(url:find("/graphql", 1, true) ~= nil, url)
      return {status = 403, headers = {}, raw_headers = {},
        body = '{"message":"This GraphQL query is not enabled for this '
        .. 'session — only the pinned set of PR-review operations is '
        .. 'served"}', url = url}
      as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 67, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 67, "cafe1234",
    "reviewer-a")
  api.transport = original
  restore_token(prior)
  assert(code == 0, "a refused landing still exits 0: " .. printed)
  assert(printed:find("landing failed", 1, true) ~= nil, "got: " .. printed)
  assert(printed:find("HTTP 403", 1, true) ~= nil, "got: " .. printed)
  assert(printed:find("/graphql", 1, true) ~= nil, "got: " .. printed)
  local it = check.must(store.load(s, leaf))
  assert(it.verdict == "accept", "the verdict is recorded, not lost: " .. printed)
  assert(it.resolution == "", "no completion — nothing landed")
end

-- A merge PUT can fail outright with neither 405 nor 409 (a validation
-- error GitHub answers 422 with, say) — no auto-merge fallback applies,
-- but the same rule holds: record first, report the landing failure on
-- the line, never refuse the verb over it.
local function test_accept_records_when_merge_put_fails_outright()
  local s, leaf = claimed_leaf("land-merge-422")
  local writes = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(_url: string,
        _opts: fetch.Options): fetch.Response | nil, fetch.Error
      writes = writes + 1
      return {status = 422, headers = {}, raw_headers = {},
        body = '{"message":"Pull Request is not mergeable"}', url = _url}
      as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 68, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 68, "cafe1234",
    "reviewer-a")
  api.transport = original
  restore_token(prior)
  assert(code == 0, "a refused landing still exits 0: " .. printed)
  assert(writes == 1, "one merge PUT, no auto-merge fallback for a 422")
  assert(printed:find("landing failed", 1, true) ~= nil, "got: " .. printed)
  assert(printed:find("HTTP 422", 1, true) ~= nil, "got: " .. printed)
  local it = check.must(store.load(s, leaf))
  assert(it.verdict == "accept", "the verdict is recorded, not lost: " .. printed)
  assert(it.resolution == "", "no completion — nothing landed")
end

-- `--no-land` skips the GitHub write entirely: no merge is attempted,
-- and the accept records exactly as it did before this item, for a
-- repo the token cannot merge.
local function test_no_land_skips_the_github_write()
  local s, leaf = claimed_leaf("land-skip")
  local writes = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(_url: string,
        _opts: fetch.Options): fetch.Response | nil, fetch.Error
      writes = writes + 1
      assert(false, "should never be called")
      return nil, nil
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 63, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 63, "cafe1234",
    "reviewer-a", "", true)
  api.transport = original
  restore_token(prior)
  assert(code == 0, "got: " .. tostring(printed))
  assert(writes == 0, "--no-land makes no GitHub write")
  local it = check.must(store.load(s, leaf))
  assert(it.resolution == "", "no land means no completion")
end

-- request-changes and reject against a real PR need `--body FILE` —
-- there is no formal review to post without one, and posting a plain
-- comment never satisfies a rework hand-back's own check for it.
local function test_request_changes_without_body_is_refused()
  local s, leaf = claimed_leaf("land-nobody")
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(_url: string,
        _opts: fetch.Options): fetch.Response | nil, fetch.Error
      assert(false, "should never be called")
      return nil, nil
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 64, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "request changes", 64,
    "cafe1234", "reviewer-a")
  api.transport = original
  restore_token(prior)
  assert(code ~= 0, "no --body is refused")
  assert(printed:find("--body FILE", 1, true) ~= nil, "got: " .. printed)
  local it = check.must(store.load(s, leaf))
  assert(it.verdict == "", "the refusal recorded nothing")
end

-- With `--body FILE`, request-changes posts the formal review pinned
-- to the judged head, carrying the file's own text.
local function test_request_changes_posts_the_formal_review()
  local s, leaf = claimed_leaf("land-review")
  local body_path = fs.join(fixture.tmpdir, "land-review-body.md")
  assert(fs.write(body_path, "the concrete gaps, quoted with file:line"))
  local posts = 0
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(url: string,
        opts: fetch.Options): fetch.Response | nil, fetch.Error
      posts = posts + 1
      assert(url:find("/repos/acme/widgets/pulls/65/reviews", 1, true) ~= nil, url)
      local decoded = json.decode(opts.body) as {string: any} -- cast: a decoded JSON object, known by construction
      assert(decoded["event"] == "REQUEST_CHANGES"
        and decoded["body"] == "the concrete gaps, quoted with file:line",
        "the payload carries the file's own text")
      return {status = 200, headers = {}, raw_headers = {}, body = "{}",
        url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 65, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "request changes", 65,
    "cafe1234", "reviewer-a", body_path)
  api.transport = original
  restore_token(prior)
  assert(code == 0, "got: " .. tostring(printed))
  assert(posts == 1, "one review POST")
  local it = check.must(store.load(s, leaf))
  assert(it.verdict == "request changes", "the send-back stands")
end

-- A reject posts the same formal review, then closes the request —
-- both against the judged PR, in that order.
local function test_reject_posts_the_review_then_closes_the_pr()
  local s, leaf = claimed_leaf("land-reject")
  local body_path = fs.join(fixture.tmpdir, "land-reject-body.md")
  assert(fs.write(body_path, "the approach was fundamentally wrong"))
  local order: {string} = {}
  local original = api.transport
  local prior = stub_token()
  api.transport = fake_transport(leaf, {}, function(_url: string,
        opts: fetch.Options): fetch.Response | nil, fetch.Error
      order[#order + 1] = opts.method
      return {status = 200, headers = {}, raw_headers = {}, body = "{}",
        url = _url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  assert(verbs.cmd_take(s, leaf, "session-a", 66, false, "") == 0)
  local code, printed = verdict_and_capture(s, leaf, "reject", 66, "cafe1234",
    "reviewer-a", body_path)
  api.transport = original
  restore_token(prior)
  assert(code == 0, "got: " .. tostring(printed))
  assert(#order == 2 and order[1] == "POST" and order[2] == "PATCH",
    "the review posts before the close: " .. table.concat(order, ", "))
  local it = check.must(store.load(s, leaf))
  assert(it.claim == "" and it.pr == 0 and it.verdict == "",
    "nothing stands after a reject")
end
