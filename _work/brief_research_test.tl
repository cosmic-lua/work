#!/usr/bin/env cosmic
-- The review brief of a research handover: `result` names a board
-- commit whose message body is the findings, and the brief judges that
-- commit — the full review, the findings verbatim beside the spec, and
-- a posture that checks findings rather than a diff. A
-- product commit beside it is still the handover; a legacy spec digest
-- in `result` names no commit and still refuses; neither recorded
-- refuses as it always did. This sibling keeps brief_test's existing
-- cases below the 500-line cap.
local brief = require("_work.brief")
local brieftext_review = require("_work.brieftext_review")
local check = require("cosmic.check")
local child = require("cosmic.child")
local doctrine = require("_work.doctrine")
local evidence = require("_work.commit_evidence")
local fixture = require("_work.fixture")
local flow = require("_work.commit_flow_fixture")
local fs = require("cosmic.fs")
local gittake = require("_work.gittake")
local gitverdict = require("_work.gitverdict")
local item = require("_work.item")
local publish = require("_work.publish")
local spec = require("_work.spec")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local BASE < const > = ("a"):rep(40)
local HEAD < const > = ("b"):rep(40)
local FINDINGS < const > = [[
## Findings

The probe reproduced: three of four representative bodies disagree.
Recommend one parser over a declared heading vocabulary.]]

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
  -- A pre-format-5 value: a digest of the spec blob, which resolves to
  -- no board commit at all — exactly the legacy shape under test.
  it.result = spec.revision(spec.document(store.read_spec(s, id)))
  assert(item.record_involvement(it.builders, flow.BUILDER))
  assert(storewrite.save(s, it, "take old result:" .. it.result))
  return it.result
end

local function assert_refusal(s: store.Store, id: string, path?: string)
  local code, out = capture(s, "review", id, path)
  assert(code == 1, out)
  assert(out:find(id:sub(1, 8) .. "'s research result ", 1, true) ~= nil
    and out:find(" is not a board commit — a legacy spec digest; hand the "
      .. "research over again with `take " .. id:sub(1, 8)
      .. " --result` to re-type it", 1, true) ~= nil, out)
  assert(out:find("You are", 1, true) == nil, "refusal must not emit a body")
  assert(out:find("claim it as", 1, true) == nil, "refusal must not mint a label")
end

--- The research handover as the verbs make it: the claim holder writes
--- the findings as an entry on the item's own ref, then `take ID
--- --result` records that tip — so `result` is a board commit whose
--- message body is the findings, and `handover_head` stays empty.
--- @param s store.Store The store
--- @param id string The item
--- @param findings string The entry's prose
--- @return string The board commit `result` records
local function research_result(s: store.Store, id: string, findings: string): string
  fixture.claim_item(s, id, "session-a", BASE)
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, "session-a"))
  assert(storewrite.save(s, it,
      ("note %s by session-a\n\n%s"):format(id:sub(1, 8), findings)))
  it = check.must(store.load(s, id))
  assert(gittake.take_result(s, it, "session-a", 0) == 0, "the handover is recorded")
  it = check.must(store.load(s, id))
  assert((it.result or "") ~= "" and (it.handover_head or "") == "",
    "a research handover records a board commit and no product commit")
  return it.result
end

--- Move the claim from the builder to a reviewing session, as the
--- orchestrator does between a handover and `brief review ID`.
local function reclaim(s: store.Store, id: string, session: string)
  fixture.drop_claim(s, id, "session-a", "handed over")
  fixture.claim_item(s, id, session, BASE)
end

local function flat_text(text: string): string
  return (text:gsub("%s+", " "))
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
    -- A review needs distance from the builder: drop the standing build
    -- claim (an active foreign claim refuses acquisition outright) and
    -- re-claim as the reviewer before the brief will fill one.
    assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
    assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
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
  -- A review needs distance from the builder: drop the standing build
  -- claim (an active foreign claim refuses acquisition outright) and
  -- re-claim as the reviewer before the brief will fill one.
  assert(flow.claim(s, id, flow.BUILDER, p, "drop") == 0)
  assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
  local code, out = capture(s, "review", id)
  assert(code == 0, out)
  assert_exact_review(out, p.head)
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.next_head,
      flow.REVIEWER, false, "", p.root) ~= 0, "a different head is not the handover")
  assert(gitverdict.cmd_verdict_commit(s, id, "accept", p.head,
      flow.REVIEWER, false, "", p.root) == 0)
  assert(check.must(store.load(s, id)).verdict_head == p.head)
  assert(store.close(s))
end

-- The change this file is evidence for: a research handover is
-- reviewable. Its brief is the FULL review — never the mechanical
-- script, whose probe diffs in the product checkout — judging the board
-- commit, with the findings verbatim under their own wording and the
-- diff case's wording absent.
local function test_a_research_handover_earns_the_full_review_of_its_findings()
  local s = fixture.init_state_repo("brief-research-findings")
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  local result = research_result(s, id, FINDINGS)
  reclaim(s, id, "session-b")
  local before = check.must(store.git_ok(s, {"show-ref"})).stdout
  local code, out = capture(s, "review", id)
  assert(code == 0, out)
  assert(check.must(store.git_ok(s, {"show-ref"})).stdout == before, "a brief is a read")
  assert_exact_review(out, result)
  assert(out:find("---\n" .. FINDINGS .. "\n---", 1, true) ~= nil,
    "the findings ride the brief verbatim, fenced like the spec: " .. out)
  assert(out:find("Do exactly this.", 1, true) ~= nil, "beside the spec: " .. out)
  assert(out:find("This is a research handover", 1, true) ~= nil
    and out:find("## The spec these findings are supposed to answer (verbatim)", 1, true) ~= nil,
    "the research wording names the findings and the spec they answer: " .. out)
  assert(flat_text(out):find("the clone at `" .. fs.absolute_path(s.root) .. "`", 1, true) ~= nil,
    "and says which repository the commit lives in: " .. out)
  assert(out:find("The caller has made this exact commit available", 1, true) == nil
    and out:find("## The spec this PR is supposed to satisfy", 1, true) == nil,
    "the diff case's wording is not used: " .. out)
  assert(out:find("the posture is ADVERSARIAL", 1, true) ~= nil
    and out:find("a numbered script", 1, true) == nil
    and out:find("git show", 1, true) == nil,
    "the full review is selected, never the mechanical script: " .. out)
  -- The rest of the review follows the deliverable too: what a findings
  -- review checks, and no diff-shaped instruction a research reviewer
  -- cannot carry out — no diff to list, no guard to mutate, no worktree,
  -- and verdict lines naming no `--repo-dir`.
  for _, diff_only in ipairs({"The diff is the Change", "cosmic --find",
      "Mutation-test at least one guard", "fresh checkout", "<WORKTREE>",
      "--repo-dir", "o/3p"}) do
    assert(out:find(diff_only, 1, true) == nil,
      "a research review carries no diff instruction: " .. diff_only .. "\n" .. out)
  end
  for _, wanted in ipairs({"names its command, and the command reproduces",
      "follows from the measurements and not past them",
      "Nothing the spec asked to be measured is missing",
      "prospective evidence for the item's parent chain"}) do
    assert(out:find(wanted, 1, true) ~= nil,
      "a research review says what a findings review checks: " .. wanted .. "\n" .. out)
  end
  assert(out:find("--head " .. result .. " --session session-b\n", 1, true) ~= nil,
    "the verdict lines name the board commit and the session, nothing more: " .. out)
  -- A product commit recorded beside it is the handover: the brief
  -- judges that commit and carries no findings.
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  it.handover_head = HEAD
  assert(storewrite.save(s, it, ("take %s by session-a head:%s"):format(
        id:sub(1, 8), HEAD:sub(1, 12))))
  local both_code, both = capture(s, "review", id)
  assert(both_code == 0, both)
  assert_exact_review(both, HEAD)
  assert(both:find(FINDINGS, 1, true) == nil
    and both:find("This is a research handover", 1, true) == nil
    and both:find("The caller has made this exact commit available", 1, true) ~= nil,
    "both recorded, the product commit is what the review judges: " .. both)
  assert(both:find("Mutation-test at least one guard", 1, true) ~= nil
    and both:find("--repo-dir", 1, true) ~= nil,
    "and takes the diff posture, mutation step and --repo-dir included: " .. both)
  -- Neither recorded refuses exactly as before.
  it = check.must(store.load(s, id))
  it.handover_head, it.result = "", ""
  assert(storewrite.save(s, it, "clear both handovers"))
  local none_code, none = capture(s, "review", id)
  assert(none_code == 1, none)
  assert(none:find(id:sub(1, 8) .. " has no handover recorded — `take "
      .. id:sub(1, 8) .. " --head SHA` is what a commit review judges", 1, true) ~= nil, none)
  assert(store.close(s))
end

-- A commit `result` names whose body carries no prose is nothing to
-- judge: refused with the way to record findings, never rendered with
-- an empty fence.
local function test_a_result_commit_without_findings_is_refused()
  local s = fixture.init_state_repo("brief-research-bodyless")
  local _, id = fixture.root_with_leaf(s)
  fixture.give_spec(s, id)
  fixture.claim_item(s, id, "session-a", BASE)
  local it = check.must(store.load(s, id))
  assert(item.record_involvement(it.builders, "session-a"))
  -- The tip as claimed: a real board commit, its body only trailers.
  local tip = s.leased_sha[id] or ""
  assert(#tip == 40, "the fixture observed a tip: " .. tip)
  it.result = tip
  assert(storewrite.save(s, it, ("take %s by session-a result:%s"):format(
        id:sub(1, 8), tip:sub(1, 7))))
  reclaim(s, id, "session-b")
  local code, out = capture(s, "review", id)
  assert(code == 1, out)
  assert(out:find(id:sub(1, 8) .. "'s research handover " .. tip:sub(1, 12)
      .. " carries no findings in its message body — record them with `log "
      .. id:sub(1, 8) .. " --add FILE`, then hand over again with `take "
      .. id:sub(1, 8) .. " --result`", 1, true) ~= nil, out)
  assert(out:find("You are", 1, true) == nil, "refusal must not emit a body")
  assert(store.close(s))
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
  assert(storewrite.save(s, it, "remove spec", {change = "", non_goals = ""}))
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

-- The doctrine states the rule the brief now holds — a review judges a
-- commit, and which repository it lives in follows from the
-- deliverable — and the research wording is its own template spliced
-- into the one full review, not a second review template.
local function test_research_doctrine_and_template_state_the_board_commit_rule()
  local page = check.must(doctrine.page("review"))
  assert(page:find([[A review judges a commit either way — which repository it lives in
follows from the deliverable — and a research handover's brief carries the
commit's message body verbatim beside the spec it answers.]], 1, true) ~= nil, page)
  assert(page:find("no review brief is available", 1, true) == nil,
    "the refusal stance is gone from the doctrine: " .. page)
  assert(brieftext_review.REVIEW:find("{{.reviewing}}", 1, true) ~= nil
    and brieftext_review.REVIEW:find("The caller has made", 1, true) == nil,
    "the full review splices its section rather than carrying one wording")
  assert(brieftext_review.REVIEW:find("{{.posture}}", 1, true) ~= nil
    and brieftext_review.REVIEW:find("Mutation-test", 1, true) == nil
    and brieftext_review.REVIEW:find("{{.worktree}}", 1, true) == nil,
    "the full review splices its posture rather than carrying one wording")
  assert(brieftext_review.POSTURE_DIFF:find("--repo-dir {{.worktree}}", 1, true) ~= nil,
    "the diff posture mutates from the reviewer's worktree and records against it")
  assert(brieftext_review.POSTURE_RESEARCH:find("{{.worktree}}", 1, true) == nil
    and brieftext_review.POSTURE_RESEARCH:find("--repo-dir", 1, true) == nil
    and brieftext_review.POSTURE_RESEARCH:find("Mutation-test", 1, true) == nil,
    "the research posture has no worktree, no --repo-dir and no mutation step")
  assert(brieftext_review.REVIEWING_RESEARCH:find("{{.findings}}", 1, true) ~= nil,
    "the research wording carries the findings")
  assert(brieftext_review.REVIEWING_DIFF:find("{{.claim_base}}..{{.head_sha}}", 1, true) ~= nil,
    "the diff wording carries the product commit range")
end
