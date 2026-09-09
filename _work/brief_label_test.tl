#!/usr/bin/env cosmic
-- Label coverage lives beside brief_test: the formatter/history helper is
-- the bounded split that keeps both production and existing tests under cap.
local brief = require("_work.brief")
local brief_label = require("_work.brief_label")
local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local env = require("cosmic.env")
local events = require("_work.events")
local fixture = require("_work.fixture")
local flow = require("_work.commit_flow_fixture")
local fs = require("cosmic.fs")
local gitverdict = require("_work.gitverdict")
local item = require("_work.item")
local publish = require("_work.publish")
local session = require("_work.session")
local spec = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")

local HEAD < const > = ("b"):rep(40)

local function capture(s: store.Store, kind: string, id: string,
    path?: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(brief.cmd_brief, s, kind, id, path)
  _G.print = old_print
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function fresh(name: string): store.Store, string
  local s = fixture.init_state_repo("brief-label-" .. name)
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local it = check.must(store.load(s, id))
  it.claim_base = ("a"):rep(40)
  it.handover_head = HEAD
  assert(storewrite.save(s, it, "take " .. id:sub(1, 8) .. " head:" .. HEAD))
  return s, id
end

-- A historical subject needs a real changed tree, not save's no-op success.
local function event(s: store.Store, id: string, subject: string)
  local it = check.must(store.load(s, id))
  it.title = it.title .. "."
  local ok, err = storewrite.save(s, it, subject)
  assert(ok and not store.is_noop(err), err)
end

local function expected(id: string, round: integer): string
  local label = "review-" .. tail.bare(id) .. "-01234567"
  return round == 1 and label or label .. "-" .. tostring(round)
end

local function assert_body(body: string, label: string)
  assert(body:match("claimed under session `([^`]+)`") == label,
    "body session must equal " .. label)
  local count = 0
  for actual in body:gmatch("%-%-session ([%w_-]+)") do
    assert(actual == label, "verdict session must equal " .. label .. ", got " .. actual)
    count = count + 1
  end
  assert(count > 0, "a verdict command must carry the session")
end

local function assert_review(s: store.Store, id: string, round: integer)
  assert(env.set("GITBOARD_SESSION", "0123456789abcdef"))
  local code, out = capture(s, "review", id)
  assert(code == 0, out)
  local label = expected(id, round)
  assert_body(out, label)
  assert(out:match("claim it as ([%w_-]+)") == label,
    "closing label must equal " .. label)
  local path = fs.join(s.root, "chosen-output.md")
  local file_code, file_out = capture(s, "review", id, path)
  assert(file_code == 0, file_out)
  assert(file_out:find("written to " .. path .. ",", 1, true) ~= nil, file_out)
  assert(file_out:match("claim it as ([%w_-]+)") == label, file_out)
  assert_body(check.must(fs.read(path)), label)
  assert(env.unset("GITBOARD_SESSION"))
end

local function test_round_one_and_two_verdicts_are_exact_and_read_only()
  local s, id = fresh("rounds")
  assert_review(s, id, 1)
  event(s, id, "verdict " .. id:sub(1, 8) .. " request-changes head:" .. HEAD)
  event(s, id, "spec changed between verdicts")
  event(s, id, "verdict " .. id:sub(1, 8) .. " accept head:" .. HEAD)
  local before = check.must(store.git_ok(s, {"show-ref"})).stdout
  assert_review(s, id, 3)
  assert_review(s, id, 3)
  assert(check.must(store.git_ok(s, {"show-ref"})).stdout == before,
    "brief reads must not allocate rounds or move refs")
  assert(store.close(s))
end

local function test_cross_head_handover_does_not_reset_the_round()
  local s, id, p = flow.fresh("brief-label-cross-head")
  check.must(store.git_ok(s, {"config", "--local", "--add", "gitboard.repository",
        "acme/widgets=" .. p.root}))
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.unrelated,
      flow.REVIEWER, false, "", p.root) ~= 0, "refused verdicts add no round")
  assert(gitverdict.cmd_verdict_commit(s, id, "request changes", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.next_head) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.next_head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  assert(check.must(store.load(s, id)).verdict == "", "new handover clears acceptance")
  local code, out = capture(s, "review", id)
  assert(code == 0 and out:find("git show", 1, true) ~= nil,
    "the mechanical commit review template is exercised")
  assert_review(s, id, 3)
  assert(store.close(s))
end

local function test_legacy_research_and_current_subjects_share_one_counter()
  local s, id = fresh("legacy")
  for _, subject in ipairs({
      "verdict old accept pr:17 by legacy",
      "verdict old reject result:abcdef0 by researcher",
      "verdict old accept head:" .. HEAD .. " by current",
      "board: verdict migration", "prose mentions verdict", "take old by builder",
      "spec old", "drop old by builder",
    }) do
    event(s, id, subject)
  end
  assert_review(s, id, 4)
  local it = check.must(store.load(s, id))
  it.result = spec.revision(store.read_spec(s, id))
  assert(item.record_involvement(it.builders, "research-builder"))
  it.handover_head = ""
  assert(storewrite.save(s, it, "take old result:" .. it.result))
  assert_review(s, id, 4)
  assert(env.set("GITBOARD_SESSION", "0123456789abcdef"))
  for _, kind in ipairs({"builder", "research", "refine", "decompose"}) do
    local code, out = capture(s, kind, id)
    local word = kind == "builder" and "build" or kind
    assert(code == 0, out)
    assert(out:match("claim it as ([%w_-]+)") == word .. "-" .. tail.bare(id) .. "-01234567", out)
  end
  assert(env.unset("GITBOARD_SESSION"))
  assert(store.close(s))
end

local function test_cold_git_and_warm_cache_return_the_same_round()
  local s, id = fresh("cache")
  event(s, id, "verdict old accept pr:17")
  event(s, id, "verdict old reject result:abcdef0")
  assert(store.close(s))
  cachedb.wipe(s.root)
  assert(events.read(s.root, id) == nil, "no cache can serve the cold read")
  assert_review(s, id, 3)
  assert(events.read(s.root, id) == nil, "brief cold reads do not build a cache")
  local c = check.must(cache.rebuild(s.root))
  assert(cache.close(c))
  assert(events.read(s.root, id) ~= nil, "the warm history cache is valid")
  assert_review(s, id, 3)
  assert(store.close(s))
end

local function test_history_failure_refuses_without_writing_and_spares_other_kinds()
  local s, id = fresh("failure")
  local old_history = publish.history
  local calls = 0
  publish.history = function(_s: store.Store, _id?: string): {publish.Event} | nil, string
    calls = calls + 1
    return nil, "injected history read failure"
  end
  local ok, err = pcall(function()
      local path = fs.join(s.root, "keep-output.md")
      assert(fs.write(path, "keep me"))
      local code, out = capture(s, "review", id, path)
      assert(code ~= 0 and out:find("gitboard-brief:", 1, true) ~= nil, out)
      assert(out:find("injected history read failure", 1, true) ~= nil, out)
      assert(out:find("claimed under session", 1, true) == nil, out)
      assert(check.must(fs.read(path)) == "keep me", "refusal must not truncate output")
      local absent = fs.join(s.root, "absent-output.md")
      local absent_code = capture(s, "review", id, absent)
      assert(absent_code ~= 0 and not fs.is_file(absent), "refusal must not create output")
      local stdout_code, stdout = capture(s, "review", id)
      assert(stdout_code ~= 0 and stdout:find("claimed under session", 1, true) == nil, stdout)
      assert(calls == 3, "one history resolution per review brief")
      for _, kind in ipairs({"builder", "research", "refine", "decompose"}) do
        local other_code, other_out = capture(s, kind, id)
        assert(other_code == 0, other_out)
      end
      assert(calls == 3, "non-review kinds never read history")
    end)
  publish.history = old_history
  assert(store.close(s))
  assert(ok, err)
end

local function test_compatibility_formatter_preserves_prefix_mapping_and_fallback()
  assert(env.set("GITBOARD_SESSION", "0123456789abcdef"))
  for _, kind in ipairs({"builder", "review", "research", "refine", "decompose", "custom"}) do
    local word = kind == "builder" and "build" or kind
    local label = word .. "-a1b2c3d4-01234567"
    assert(brief.mint_label(kind, "a1b2c3d4") == label)
    assert(brief_label.mint_label(kind, "a1b2c3d4") == label)
  end
  assert(env.set("GITBOARD_SESSION", "87654321different"))
  assert(brief.mint_label("review", "a1b2c3d4") == "review-a1b2c3d4-87654321")
  assert(env.unset("GITBOARD_SESSION"))
  local old_resolve = session.resolve
  session.resolve = function(_explicit: string | nil): string, string
    return "", "none"
  end
  local label = brief.mint_label("review", "a1b2c3d4")
  session.resolve = old_resolve
  assert(label == "review-a1b2c3d4-unnamed")
end
