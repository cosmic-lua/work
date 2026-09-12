#!/usr/bin/env cosmic
-- `verdict accept`'s landing step. Gitboard lands nothing by default:
-- the caller merges, and the verdict only records. A caller that has
-- explicitly activated provider transport (`_work.apiauth`, by naming
-- the variable holding its token) gets the landing sequence back —
-- squash-merge the judged head, arm auto-merge when GitHub refuses a
-- direct merge — with the judgment recorded FIRST, so a landing that
-- fails reports itself and never costs the verdict.
--
-- Every case fabricates its own exchange and names its own fake
-- credential variable: nothing here makes a live call or spends a real
-- token.
local api = require("_work.api")
local check = require("cosmic.check")
local env = require("cosmic.env")
local fetch = require("cosmic.fetch")
local flow = require("_work.commit_flow_fixture")
local json = require("cosmic.json")
local store = require("_work.store")
local verdict = require("_work.gitverdict")

-- The opt-in's own variable, spelled out rather than read off
-- `_work.apiauth`: this file must not require the opt-in, which the
-- boundary guard holds to one call site.
local ACTIVATION_ENV < const > = "GITBOARD_PROVIDER_TOKEN_ENV"
local TOKEN_ENV < const > = "GITBOARD_TEST_LAND_TOKEN"
local PULL_URL < const > = "https://github.com/acme/widgets/pull/7"

--- One fabricated exchange the fake transport answers with.
local record Reply
  status: integer
  body: string
end

--- What the fake transport recorded about one request.
local record Sent
  method: string
  url: string
  body: string
  authorization: string
end

--- An item handed over with a pull request URL and claimed for review.
--- `flow.fresh` sets the item's repository to `acme/widgets`, which is
--- the repository `PULL_URL` names; a case that passes another URL is
--- deliberately handing over one that disagrees with the item.
--- @param name string The fixture name
--- @param url string | nil The handover URL (defaults to `PULL_URL`)
--- @return store.Store The board
--- @return string The item id
--- @return flow.Product The product repository
local function review_ready(name: string, url?: string):
  store.Store, string, flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head, url or PULL_URL) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  return s, id, p
end

--- Name the variable holding a fake token, so the opt-in activates.
--- @return function() Put the environment back
local function opt_in(): function()
  local prior_name = env.get(ACTIVATION_ENV)
  local prior_token = env.get(TOKEN_ENV)
  assert(env.set(ACTIVATION_ENV, TOKEN_ENV))
  assert(env.set(TOKEN_ENV, "fake-token-value"))
  return function()
    if prior_name == nil then
      local _ok, _err = env.unset(ACTIVATION_ENV)
    else
      assert(env.set(ACTIVATION_ENV, prior_name))
    end
    if prior_token == nil then
      local _ok, _err = env.unset(TOKEN_ENV)
    else
      assert(env.set(TOKEN_ENV, prior_token))
    end
  end
end

--- A transport that answers each request from `replies`, keyed by
--- "METHOD /path", and records what it was asked for.
--- @param replies {string: Reply} The fabricated answers
--- @param sent {Sent} Where to record the requests, in order
--- @return function(string, fetch.Options): (fetch.Response | nil, fetch.Error)
local function fake(replies: {string: Reply}, sent: {Sent}):
  function(url: string, opts: fetch.Options): (fetch.Response | nil, fetch.Error)
  return function(url: string, opts: fetch.Options):
    fetch.Response | nil, fetch.Error
    local method = opts.method or "GET"
    local path = url:gsub("^https://api%.github%.com", "")
    sent[#sent + 1] = {method = method, url = url, body = opts.body or "",
      authorization = (opts.headers or {})["authorization"] or ""}
    local reply = replies[method .. " " .. path]
    if reply == nil then
      local why = "no fabricated reply for " .. method .. " " .. path
      return nil, why as fetch.Error -- cast: fetch.Error is an opaque string error
    end
    return {status = reply.status, headers = {}, raw_headers = {},
      body = reply.body, url = url}
    as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
  end
end

--- Record an accept with the fake transport in place, capturing the
--- verdict line it printed.
--- @param s store.Store The board
--- @param id string The item
--- @param p flow.Product The product repository
--- @param replies {string: Reply} The fabricated answers
--- @param sent {Sent} Where the requests are recorded
--- @return integer The exit code
--- @return string The verdict line
local function accept(s: store.Store, id: string, p: flow.Product,
    replies: {string: Reply}, sent: {Sent}): integer, string
  local lines: {string} = {}
  local restore = opt_in()
  local old_print = _G.print
  _G.print = function(msg: any) lines[#lines + 1] = tostring(msg) end
  local rc = verdict.cmd_verdict_commit(s, id, "accept", p.head,
    flow.REVIEWER, false, "", p.root, fake(replies, sent))
  _G.print = old_print
  restore()
  return rc, lines[#lines] or ""
end

local MERGE < const > = "PUT /repos/acme/widgets/pulls/7/merge"
local READ < const > = "GET /repos/acme/widgets/pulls/7"
local MUTATE < const > = "POST /graphql"

-- The whole sequence when GitHub merges immediately: the verdict is
-- recorded, the merge is guarded by the judged head, it rides the
-- activated transport's bearer credential, and the line names the
-- merge commit.
local function test_an_activated_accept_merges_the_judged_head()
  local s, id, p = review_ready("verdict-land-merge")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 200, body = '{"sha":"feedface1234","merged":true}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == p.head,
    "the judgment is recorded before anything is sent")
  assert(#sent == 1, ("one request, got %d"):format(#sent))
  assert(sent[1].method == "PUT" and sent[1].url:find(
      "/repos/acme/widgets/pulls/7/merge", 1, true) ~= nil, sent[1].url)
  assert(sent[1].authorization == "Bearer fake-token-value",
    "got: " .. sent[1].authorization)
  local payload = json.decode(sent[1].body) as {string: any} -- cast: a decoded JSON object, known by construction
  assert(payload["sha"] == p.head, "the merge is guarded by the judged head")
  assert(payload["merge_method"] == "squash", tostring(payload["merge_method"]))
  assert(line:find("merged feedface1234", 1, true) ~= nil, line)
end

-- Activation is scoped to the landing. The verb installs a transport
-- for its one step and takes it down again, so nothing later in the
-- process inherits a live provider connection from a verdict that
-- happened to land.
local function test_the_landing_leaves_the_process_refusing_again()
  local s, id, p = review_ready("verdict-land-scoped")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 200, body = '{"sha":"feedface1234"}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  assert(#sent == 1, "the landing went out")
  local res, err = api.call("GET", "/user", "")
  assert(res == nil and err:find("external to gitboard", 1, true) ~= nil,
    "a scoped activation outlived the verb: " .. tostring(err))
end

-- A 405 is "not directly mergeable right now" (branch protection, a
-- merge queue), not a failure: the accept still stands, so the
-- fallback reads the request for its node id and arms auto-merge.
local function test_a_refused_merge_arms_auto_merge()
  local s, id, p = review_ready("verdict-land-auto")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 405, body = '{"message":"Pull Request is not mergeable"}'},
      [READ] = {status = 200, body = ('{"node_id":"PR_node_7","number":7,'
          .. '"head":{"sha":"%s"}}'):format(p.head)},
      [MUTATE] = {status = 200, body = '{"data":{"enablePullRequestAutoMerge":{}}}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  assert(check.must(store.load(s, id)).verdict == "accept", "the accept stands")
  assert(#sent == 3, ("merge, read, mutate; got %d"):format(#sent))
  assert(sent[3].method == "POST" and sent[3].url:find("/graphql", 1, true) ~= nil,
    sent[3].url)
  local payload = json.decode(sent[3].body) as {string: any} -- cast: a decoded JSON object, known by construction
  local variables = payload["variables"] as {string: any} -- cast: a decoded JSON object, known by construction
  assert(variables["id"] == "PR_node_7", tostring(variables["id"]))
  assert(line:find("auto-merge armed", 1, true) ~= nil, line)
  assert(line:find("landing failed", 1, true) == nil, line)
end

-- Auto-merge refusing is the one thing the fallback must not swallow:
-- the verdict still stands, and the line hands the landing back with
-- GitHub's own reason on it.
local function test_auto_merge_refusing_surfaces_the_error()
  local s, id, p = review_ready("verdict-land-refused")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 405,
        body = '{"message":"Required status check is expected"}'},
      [READ] = {status = 200, body = ('{"node_id":"PR_node_7","number":7,'
          .. '"head":{"sha":"%s"}}'):format(p.head)},
      [MUTATE] = {status = 200,
        body = '{"errors":[{"message":"Auto-merge is not allowed"}]}'},
    }, sent)
  assert(rc == 0, "a failed landing never costs the verdict: " .. line)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == p.head,
    "the judgment survives its landing")
  assert(line:find("landing failed", 1, true) ~= nil, line)
  assert(line:find("Auto-merge is not allowed", 1, true) ~= nil, line)
  assert(line:find("land it by hand", 1, true) ~= nil, line)
end

-- A merge refusal that is NOT "held back" — a permission failure, say
-- — is a real error the caller must see, never retried as auto-merge.
local function test_a_real_merge_failure_is_not_retried()
  local s, id, p = review_ready("verdict-land-forbidden")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 403, body = '{"message":"Resource not accessible"}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  assert(#sent == 1, ("a 403 is not a fallback; got %d requests"):format(#sent))
  assert(line:find("landing failed", 1, true) ~= nil, line)
  assert(line:find("HTTP 403", 1, true) ~= nil, line)
end

-- The default, and the whole point of the opt-in: with no variable
-- named, nothing is sent and the line is exactly the one every other
-- verdict test reads.
local function test_without_the_opt_in_nothing_is_sent()
  local s, id, p = review_ready("verdict-land-default")
  local prior_name = env.get(ACTIVATION_ENV)
  local _unset, _uerr = env.unset(ACTIVATION_ENV)
  local sent: {Sent} = {}
  local lines: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) lines[#lines + 1] = tostring(msg) end
  local rc = verdict.cmd_verdict_commit(s, id, "accept", p.head,
    flow.REVIEWER, false, "", p.root, fake({}, sent))
  _G.print = old_print
  if prior_name ~= nil then assert(env.set(ACTIVATION_ENV, prior_name)) end
  assert(rc == 0, "got: " .. (lines[#lines] or ""))
  assert(#sent == 0, "an unactivated accept writes nothing to a provider")
  assert(lines[#lines] == ("gitboard-verdict: accept on %s at %s: recorded")
    :format(id:sub(1, 8), p.head:sub(1, 12)), lines[#lines])
  assert(check.must(store.load(s, id)).verdict == "accept")
end

-- An activated caller still lands nothing when the item records no
-- pull request: the URL is the only place the model names one, and
-- there is nothing to guess from a commit id.
local function test_an_item_with_no_pull_request_lands_nothing()
  local s, id, p = flow.fresh("verdict-land-nourl")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {}, sent)
  assert(rc == 0, "got: " .. line)
  assert(#sent == 0, "no recorded pull request, nothing to land")
  assert(line:find("recorded", 1, true) ~= nil, line)
end

-- Landing is the accept's step alone. A request-changes verdict on the
-- same activated process writes nothing to the provider.
local function test_request_changes_never_lands()
  local s, id, p = review_ready("verdict-land-rework")
  local sent: {Sent} = {}
  local restore = opt_in()
  local old_print = _G.print
  _G.print = function(_msg: any) end
  local rc = verdict.cmd_verdict_commit(s, id, "request changes", p.head,
    flow.REVIEWER, false, "", p.root, fake({}, sent))
  _G.print = old_print
  restore()
  assert(rc == 0, "a request-changes verdict records")
  assert(#sent == 0, "only an accept has a landing to perform")
end

-- A 409 is GitHub reporting that the branch's head no longer matches
-- the sha `merge_pull` guarded the request with: the commit that was
-- judged is not the commit that would land. Auto-merge carries no head
-- guard at all, so arming it here would schedule the UNREVIEWED head
-- to land — a failure the caller has to resolve by hand, never a state
-- to wait out.
local function test_a_moved_head_is_reported_not_armed()
  local s, id, p = review_ready("verdict-land-moved")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 409, body = '{"message":"Head branch was modified"}'},
      [READ] = {status = 200, body = '{"node_id":"PR_node_7","number":7}'},
      [MUTATE] = {status = 200,
        body = '{"data":{"enablePullRequestAutoMerge":{}}}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  assert(check.must(store.load(s, id)).verdict == "accept", "the accept stands")
  assert(#sent == 1,
    ("a moved head sends the merge and stops; got %d requests"):format(#sent))
  assert(line:find("auto-merge armed", 1, true) == nil,
    "a moved head must never be armed to land: " .. line)
  assert(line:find("landing failed", 1, true) ~= nil, line)
  assert(line:find("HTTP 409", 1, true) ~= nil, line)
  assert(line:find("land it by hand", 1, true) ~= nil, line)
end

-- The item's `repo` is what says where a landing may write. The
-- recorded URL is free-form text whoever held the claim typed at
-- handover and nothing reconciles it with the item when it is written,
-- so a URL at a different repository must land nothing rather than
-- aim the squash somewhere the Access line never named.
local function test_a_url_at_another_repository_lands_nothing()
  local s, id, p = review_ready("verdict-land-elsewhere",
    "https://github.com/other-org/other-repo/pull/7")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 200, body = '{"sha":"feedface1234","merged":true}'},
      ["PUT /repos/other-org/other-repo/pulls/7/merge"] =
      {status = 200, body = '{"sha":"feedface1234","merged":true}'},
    }, sent)
  assert(rc == 0, "a refused landing never costs the verdict: " .. line)
  assert(check.must(store.load(s, id)).verdict == "accept", "the accept stands")
  assert(#sent == 0,
    ("a disagreeing URL writes nowhere; got %d requests"):format(#sent))
  assert(line:find("landing failed", 1, true) ~= nil, line)
  assert(line:find("other-org/other-repo", 1, true) ~= nil, line)
  assert(line:find("acme/widgets", 1, true) ~= nil, line)
  assert(line:find("merged", 1, true) == nil, line)
end

-- A 405 says the merge is not mergeable RIGHT NOW; it does not say the
-- request's head is still the one the merge was guarded with. Both
-- arming routes are head-blind — the GraphQL mutation addresses the
-- request by node id and its REST fallback carries no sha — so arming
-- over a head that has moved would schedule an unreviewed commit to
-- land whenever the checks clear. The read the fallback already
-- performs for the node id settles it: the mismatch is reported and no
-- mutation goes out.
local function test_a_405_on_a_moved_head_arms_nothing()
  local s, id, p = review_ready("verdict-land-405-moved")
  local sent: {Sent} = {}
  local rc, line = accept(s, id, p, {
      [MERGE] = {status = 405,
        body = '{"message":"Pull Request is not mergeable"}'},
      [READ] = {status = 200, body = '{"node_id":"PR_node_7","number":7,'
        .. '"head":{"sha":"0bad0bad0bad0bad0bad0bad0bad0bad0bad0bad"}}'},
      [MUTATE] = {status = 200,
        body = '{"data":{"enablePullRequestAutoMerge":{}}}'},
    }, sent)
  assert(rc == 0, "got: " .. line)
  assert(check.must(store.load(s, id)).verdict == "accept", "the accept stands")
  assert(#sent == 2,
    ("the merge and the read, and nothing armed; got %d requests")
    :format(#sent))
  assert(sent[2].method == "GET" and sent[2].url:find(
      "/repos/acme/widgets/pulls/7", 1, true) ~= nil, sent[2].url)
  assert(line:find("auto-merge armed", 1, true) == nil,
    "an unreviewed head must never be armed to land: " .. line)
  assert(line:find("landing failed", 1, true) ~= nil, line)
  assert(line:find("0bad0ba", 1, true) ~= nil,
    "the head that would land is named: " .. line)
  assert(line:find("auto-merge was not armed", 1, true) ~= nil, line)
  assert(line:find("land it by hand", 1, true) ~= nil, line)
end
