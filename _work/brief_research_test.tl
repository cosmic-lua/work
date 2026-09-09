#!/usr/bin/env cosmic
-- Research migration is an exact-head review concern; this sibling keeps
-- brief_test's existing cases below the 500-line cap.
local brief = require("_work.brief")
local brieftext_review = require("_work.brieftext_review")
local check = require("cosmic.check")
local child = require("cosmic.child")
local doctrine = require("_work.doctrine")
local evidence = require("_work.commit_evidence")
local fixture = require("_work.fixture")
local flow = require("_work.commit_flow_fixture")
local fs = require("cosmic.fs")
local gitverdict = require("_work.gitverdict")
local item = require("_work.item")
local publish = require("_work.publish")
local spec = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

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

local function legacy_result(s: store.Store, id: string): string
  local it = check.must(store.load(s, id))
  it.result = spec.revision(store.read_spec(s, id))
  assert(item.record_involvement(it.builders, flow.BUILDER))
  assert(storewrite.save(s, it, "take old result:" .. it.result))
  return it.result
end

local function assert_refusal(s: store.Store, id: string, path?: string)
  local code, out = capture(s, "review", id, path)
  assert(code == 1, out)
  assert(out:find(id:sub(1, 8)
      .. " has a legacy research result but no commit handover — the caller must "
      .. "supply the applying product commit with `take " .. id:sub(1, 8)
      .. " --head SHA`", 1, true) ~= nil, out)
  assert(out:find("You are", 1, true) == nil, "refusal must not emit a body")
  assert(out:find("claim it as", 1, true) == nil, "refusal must not mint a label")
end

local function test_result_only_refuses_without_output_or_state_changes()
  local s = fixture.init_state_repo("brief-research-refusal")
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local digest = legacy_result(s, id)
  local before = check.must(store.git_ok(s, {"show-ref"})).stdout
  local sentinel = fs.join(s.root, "sentinel.md")
  local absent = fs.join(s.root, "absent.md")
  assert(fs.write(sentinel, "keep this output\n"))
  -- History is deliberately unavailable: refusal must precede label reads.
  local old_history = publish.history
  publish.history = function(_s: store.Store, _id: string): {publish.Event} | nil, string
    error("result-only review must not read verdict history")
  end
  local ok, err = pcall(function()
      assert_refusal(s, id)
      assert_refusal(s, id, sentinel)
      assert_refusal(s, id, absent)
    end)
  publish.history = old_history
  if not ok then error(err, 0) end
  assert(check.must(fs.read(sentinel)) == "keep this output\n")
  assert(not fs.is_file(absent), "refusal must not create --out")
  assert(check.must(store.git_ok(s, {"show-ref"})).stdout == before)
  assert(store.close(s))
  s = check.must(store.open(s.root))
  local it = check.must(store.load(s, id))
  assert(it.result == digest and (it.handover_head or "") == "",
    "legacy metadata must survive reopening without becoming a commit")
  assert_refusal(s, id)
  local code, out = capture(s, "research", id)
  assert(code == 0, out)
  assert(out:find("never at\na `gitboard` command", 1, true) ~= nil, out)
  assert(check.must(store.git_ok(s, {"show-ref"})).stdout == before)
  assert(storewrite.save(s, it, "remove spec", ""))
  code, out = capture(s, "review", id)
  assert(code == 1 and out:find("has no spec sidecar", 1, true) ~= nil, out)
  assert(out:find("legacy research result", 1, true) == nil, out)
  fixture.give_spec(s, id)
  it = check.must(store.load(s, id))
  it.result = ""
  assert(storewrite.save(s, it, "clear legacy result"))
  code, out = capture(s, "review", id)
  assert(code == 1, out)
  assert(out:find(id:sub(1, 8) .. " has no handover recorded — `take "
      .. id:sub(1, 8) .. " --head SHA` is what a commit review judges", 1, true) ~= nil, out)
  assert(store.close(s))
end

local function assert_exact_review(body: string, head: string)
  local commands = 0
  for actual in body:gmatch("%-%-head (%x+)") do
    assert(actual == head, "every verdict must judge the handover SHA")
    commands = commands + 1
  end
  assert(commands == 3, "accept, request-changes, and reject must all name a head")
  local flat = body:gsub("%s+", " ")
  assert(flat:find("stale by construction; never read, grep or build", 1, true) ~= nil, body)
  assert(flat:find("The captures landed", 1, true) == nil, body)
  assert(flat:find("git for-each-ref", 1, true) == nil, body)
  assert(flat:find("No `--pr` and no `--head`", 1, true) == nil, body)
end

local function test_mixed_result_and_head_render_identically_for_both_templates()
  for _, mechanical in ipairs({false, true}) do
    local name = mechanical and "mechanical" or "full"
    local s, id, p = flow.fresh("brief-research-mixed-" .. name)
    assert(flow.claim(s, id, flow.BUILDER, p) == 0)
    assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
    if mechanical then
      check.must(store.git_ok(s, {"config", "--local", "--add", "gitboard.repository",
            "acme/widgets=" .. p.root}))
    end
    legacy_result(s, id)
    local before = check.must(store.git_ok(s, {"show-ref"})).stdout
    local code, mixed = capture(s, "review", id)
    assert(code == 0, mixed)
    assert_exact_review(mixed, p.head)
    assert((mixed:find("git show", 1, true) ~= nil) == mechanical, mixed)
    assert(check.must(store.git_ok(s, {"show-ref"})).stdout == before)
    local it = check.must(store.load(s, id))
    assert(it.handover_head == p.head and it.result ~= "")
    it.result = ""
    assert(storewrite.save(s, it, "clear only result"))
    local ordinary_code, ordinary = capture(s, "review", id)
    assert(ordinary_code == 0, ordinary)
    assert(mixed == ordinary, "legacy result must not override exact-head review")
    assert(store.close(s))
  end
end

local function test_legacy_result_migrates_only_through_product_commit_handover()
  local s, id, p = flow.fresh("brief-research-migration")
  local digest = legacy_result(s, id)
  assert_refusal(s, id)
  local resolved = evidence.commit_id(p.root, digest)
  assert(resolved == nil, "a result digest is not a product commit")
  assert(flow.claim(s, id, flow.BUILDER, p) == 0)
  local ref = "refs/heads/items/" .. id
  local board_head = check.must(store.git_ok(s, {"rev-parse", ref})).stdout:gsub("%s+$", "")
  local fetched = check.must(child.run({"git", "fetch", s.root, ref}, {cwd = p.root}))
  assert(fetched.ok, fetched.stderr)
  local lineage, err = evidence.verify_lineage(p.root, p.base, board_head)
  assert(lineage == nil and err:find("does not descend from claim base", 1, true) ~= nil, err)
  assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
  local it = check.must(store.load(s, id))
  assert((it.result or "") == "" and it.handover_head == p.head)
  local found = false
  for _, event in ipairs(check.must(publish.history(s, id))) do
    if event.subject == "take old result:" .. digest then found = true end
  end
  assert(found, "migration must preserve the historical result")
  local code, out = capture(s, "review", id)
  assert(code == 0, out)
  assert_exact_review(out, p.head)
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.next_head,
      flow.REVIEWER, false, "", p.root) ~= 0, "a different head is not the handover")
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(check.must(store.load(s, id)).verdict_head == p.head)
  assert(store.close(s))
end

local function test_research_doctrine_and_template_exports_require_a_product_commit()
  local page = check.must(doctrine.page("review"))
  assert(page:find([[Research agents return recommendations; the caller applies them in the product
repository and hands over its exact commit through `take ID --head SHA`.
That commit must descend from the claim's product base. A result digest or
unrelated board item-ref commit is not a substitute. If no applying product
commit exists, no review brief is available: stop for caller preparation.
Research uses ordinary exact-head review; no result-only review template
or additional agent board-read instructions are emitted.]], 1, true) ~= nil, page)
  for key in next, brieftext_review do
    assert(key ~= "RESEARCH_REVIEW", "the result-only template export is retired")
  end
end
