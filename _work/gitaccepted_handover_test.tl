#!/usr/bin/env cosmic
-- Acceptance is evidence for one exact handover, including after reopening.
local check = require("cosmic.check")
local flow = require("_work.commit_flow_fixture")
local gitboard = require("_work.gitboard")
local gitobj = require("_work.gitobj")
local boardread = require("_work.boardread")
local itemtree = require("_work.itemtree")
local projection = require("_work.stateplan_git")
local publish = require("_work.publish")
local read = require("_work.read")
local refs = require("_work.refs")
local store = require("_work.store")

local function call(s: store.Store, ...: string): integer, string
  assert(store.close(s))
  local args: {string} = {...}
  args[#args + 1], args[#args + 2] = "--dir", s.root
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(function(): integer
      return gitboard.main(table.unpack(args))
    end)
  _G.print = old_print
  if not ok then error(code, 0) end
  assert(publish.sync(s))
  return code, table.concat(lines, "\n")
end

local function reopen(s: store.Store): store.Store
  assert(store.close(s))
  local opened = check.must(store.open(s.root))
  local _items = check.must(store.list(opened))
  return opened
end

local function accepted(name: string): store.Store, string, flow.Product
  local s, id, p = flow.fresh(name)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(call(s, "take", id, "--head", p.head, "--repo-dir", p.root,
      "--session", flow.BUILDER) == 0)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(call(s, "verdict", id, "accept", "--head", p.head,
      "--repo-dir", p.root, "--session", flow.REVIEWER) == 0)
  return reopen(s), id, p
end

local function test_new_handover_requires_its_own_acceptance_before_completion()
  local s, id, p = accepted("accepted-new-head")
  local ref = "refs/heads/state"
  local old_tip = check.must(refs.read_ref(s.root, ref))
  assert(check.must(read.substate(check.must(store.read(s)), id)) == "accepted")
  -- An external check fails: release the reviewer, reacquire for rework.
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(call(s, "take", id, "--head", p.next_head, "--repo-dir", p.root,
      "--session", flow.BUILDER) == 0)
  s = reopen(s)
  local reworked = check.must(store.load(s, id))
  assert(reworked.handover_head == p.next_head and reworked.verdict == ""
    and reworked.verdict_head == "")
  assert(check.must(read.substate(check.must(store.read(s)), id)) == "review")
  local historical = check.must(boardread.load(s.root, old_tip, id)).it
  assert(historical.verdict == "accept" and historical.verdict_head == p.head,
    "the old acceptance remains in immutable item history")
  assert(call(s, "done", id, "completed", "--landed", p.next_head,
      "--repo-dir", p.root, "--session", flow.BUILDER) ~= 0)

  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local code, out = call(s, "verdict", id, "accept", "--head", p.head,
    "--repo-dir", p.root, "--session", flow.REVIEWER)
  assert(code ~= 0 and out:find("but the handover is", 1, true), out)
  assert(call(s, "verdict", id, "accept", "--head", p.next_head,
      "--repo-dir", p.root, "--session", flow.REVIEWER) == 0)
  s = reopen(s)
  assert(check.must(store.load(s, id)).verdict_head == p.next_head)
  assert(call(s, "done", id, "completed", "--landed", p.head,
      "--repo-dir", p.root, "--session", flow.REVIEWER) ~= 0)
  assert(call(s, "done", id, "completed", "--landed", p.next_head,
      "--repo-dir", p.root, "--session", flow.REVIEWER) == 0)
  s = reopen(s)
  local completed = check.must(store.load(s, id))
  assert(completed.resolution == "completed" and completed.landed_head == p.next_head)
  assert(store.close(s))
end

local function test_same_accepted_head_and_url_update_preserve_verdict()
  local s, id, p = accepted("accepted-same-head")
  assert(call(s, "take", id, "--head", p.head, "--repo-dir", p.root,
      "--session", flow.REVIEWER) == 0)
  local code, out = call(s, "take", id, "--head", p.head, "--repo-dir", p.root,
    "--url", "https://example.test/review/2", "--session", flow.REVIEWER)
  assert(code == 0, out)
  assert(out:find("is accepted (same head; external URL updated)", 1, true),
    "a same-head metadata-only take reports the acceptance it preserves: " .. out)
  assert(not out:find("awaiting review", 1, true),
    "the durable acceptance must not be contradicted by the verdict line: " .. out)
  s = reopen(s)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "accept" and it.verdict_head == p.head)
  assert(it.external_url == "https://example.test/review/2")
  assert(store.close(s))
end

local function test_unreviewed_same_head_url_attachment_still_awaits_review()
  local s, id, p = flow.fresh("unreviewed-same-head")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  assert(call(s, "take", id, "--head", p.head, "--repo-dir", p.root,
      "--session", flow.BUILDER) == 0)
  local code, out = call(s, "take", id, "--head", p.head, "--repo-dir", p.root,
    "--url", "https://example.test/change/9", "--session", flow.BUILDER)
  assert(code == 0, out)
  assert(out:find("awaiting review", 1, true),
    "an unreviewed handover has no acceptance to preserve: " .. out)
  assert(not out:find("is accepted", 1, true), out)
  s = reopen(s)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "" and it.external_url == "https://example.test/change/9")
  assert(store.close(s))
end

local function test_new_head_after_acceptance_still_supersedes_it()
  local s, id, p = accepted("new-head-after-accept")
  assert(flow.claim(s, id, flow.REVIEWER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  local code, out = call(s, "take", id, "--head", p.next_head,
    "--repo-dir", p.root, "--session", flow.BUILDER)
  assert(code == 0, out)
  assert(out:find("awaiting review", 1, true),
    "a genuinely new head clears the stale acceptance rather than reporting it: "
    .. out)
  assert(not out:find("is accepted", 1, true), out)
  s = reopen(s)
  local it = check.must(store.load(s, id))
  assert(it.verdict == "" and it.verdict_head == ""
    and it.handover_head == p.next_head,
    "a new head must continue to clear/supersede acceptance")
  assert(store.close(s))
end

local function test_stale_acceptance_refuses_completion_and_can_be_rehanded()
  local s, id, p = accepted("accepted-stale-head")
  local it = check.must(store.load(s, id))
  it.handover_head = p.next_head
  -- Reproduce already-written inconsistent metadata without passing the
  -- ordinary writer's validation; readers deliberately tolerate old facts.
  local ref = "refs/heads/state"
  for _, judged in ipairs({"", p.head}) do
    it.verdict_head = judged
    local old = check.must(refs.read_ref(s.root, ref))
    local tree = check.must(projection.apply(s.root, old,
        {{path = "items/" .. id .. "/meta", mode = "100644", content = itemtree.encode_meta(it), delete = false}}))
    local tip = check.must(gitobj.commit_tree(s.root, {tree = tree, parents = {old},
          message = "historical stale acceptance", author_name = "fixture",
          author_email = "fixture@example.test", committer_name = "fixture",
          committer_email = "fixture@example.test"}))
    assert(refs.update_ref(s.root, ref, tip, old))
    s = reopen(s)
    -- Even an audited completion without --landed cannot reuse stale evidence.
    local code, out = call(s, "done", id, "completed", "--repo-dir", p.root,
      "--session", flow.REVIEWER, "--force", "--why", "repair")
    assert(code ~= 0 and out:find("acceptance must name the current handover", 1, true), out)
  end
  local code, out = call(s, "take", id, "--head", p.next_head,
    "--repo-dir", p.root, "--session", flow.REVIEWER)
  assert(code == 0, out)
  s = reopen(s)
  it = check.must(store.load(s, id))
  assert(it.verdict == "" and it.verdict_head == "" and it.handover_head == p.next_head)
  assert(store.close(s))
end
