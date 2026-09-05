#!/usr/bin/env cosmic
-- The verdict verb over a research handover (`take --result`, no PR):
-- the spec-revision judged, the accept outcome named `done` rather
-- than a merge it has no PR to await, and how a fresh handover
-- interacts with a standing verdict on either side. Split out of
-- `_work.gitverdict_test` to keep that file under the repo's line cap.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitspec = require("_work.gitspec")
local fs = require("cosmic.fs")
local read = require("_work.read")
local spec = require("_work.spec")
local store = require("_work.store")
local verbs = require("_work.gitverbs")
local vrd = require("_work.gitverdict")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

--- A leaf taken and handed over: claim plus PR, awaiting a verdict.
local function handed_over(s: store.Store, leaf: string, pr: integer)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", pr, false, "") == 0)
end

--- `id`'s derived one-word state, read fresh through the store.
--- @param s store.Store The store
--- @param id string The item id
--- @return string
local function state_of(s: store.Store, id: string): string
  local it = check.must(store.load(s, id))
  if (it.resolution or "") ~= "" then
    return it.resolution
  end
  check.must(store.list(s))
  local c = check.must(store.read(s))
  local st = check.must(read.state(c, id))
  if st ~= "doing" then
    return "todo"
  end
  return check.must(read.substate(c, id))
end

--- Run vrd.cmd_verdict and capture exactly what it prints via print()
--- -- the same swap-and-restore pattern `_work.gitverdict_test` uses.
--- @param s store.Store The store
--- @param id string The item under verdict
--- @param kind string accept | request changes | reject
--- @param pr integer The PR the verdict judges, 0 to use the item's own
--- @param head string The head commit the verdict judges
--- @param session string | nil The reviewing session; rides in the subject
--- @param force boolean | nil Record over the distance guard — repair only
--- @param why string | nil Why --force was needed
--- @return integer cmd_verdict's exit code
--- @return string Every print()'d line, newline-joined
local function verdict_and_capture(s: store.Store, id: string, kind: string,
    pr: integer, head: string, session?: string, force?: boolean,
    why?: string): integer, string
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
    force, why)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

-- A research handover is judged as the spec revision it recorded: the
-- verdict lands and stores that revision as `verdict_spec`; a spec
-- that moved between handover and verdict is refused the way a moved
-- PR head is, and a `--pr` offered against the handover is too.
local function test_a_research_handover_refuses_a_spec_that_moved()
  local s = init_state_repo("verdict-result-moved")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "the research handover")
  local base = fs.join(fixture.tmpdir, "result-base.md")
  assert(fs.write(base, store.read_spec(s, leaf)))
  local moved = fs.join(fixture.tmpdir, "result-moved.md")
  assert(fs.write(moved, store.read_spec(s, leaf) .. "\nOne more finding.\n"))
  assert(gitspec.cmd_spec(s, leaf, moved, base, "session-a") == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 0, "",
    "reviewer-a")
  assert(code ~= 0, "a spec that moved past the handover is not what was handed over")
  assert(printed:find("moved since its handover", 1, true) ~= nil,
    "the printed refusal says so: " .. printed)
  assert(printed:find("--result", 1, true) ~= nil,
    "and names the way forward: " .. printed)
  assert(check.must(store.load(s, leaf)).verdict == "", "and nothing was recorded")
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "handing the moved spec over again")
  local code2, printed2 = verdict_and_capture(s, leaf, "accept", 9, "cafe1234",
    "reviewer-a")
  assert(code2 ~= 0 and printed2:find("not a PR", 1, true) ~= nil,
    "a PR offered against the handover is refused: " .. printed2)
  assert(vrd.cmd_verdict(s, leaf, "accept", 0, "", "reviewer-a") == 0,
    "the re-handed spec is judged")
  local judged = check.must(store.load(s, leaf))
  assert(judged.verdict == "accept" and judged.verdict_spec == judged.result,
    "the accept records the handed-over revision as the judged spec")
  assert(judged.verdict_head == "", "and no head, there being none")
end

-- A handover's accept outcome names `done`, not a merge it has no PR
-- to await: `done` skips the merge read entirely when `pr` is 0
-- (`gitverbs.cmd_done`), so "awaiting merge" would send the session
-- looking for one that will never exist. A diff's outcome is unchanged.
local function test_a_handovers_accept_outcome_names_done_not_a_merge()
  local s = init_state_repo("verdict-result-outcome")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0)
  local code, printed = verdict_and_capture(s, leaf, "accept", 0, "",
    "reviewer-a")
  assert(code == 0, printed)
  assert(printed:find("accepted — `done ID` ends it", 1, true) ~= nil,
    "names done directly: " .. printed)
  assert(printed:find("merge", 1, true) == nil,
    "and claims no merge: " .. printed)
  local diff_s = init_state_repo("verdict-diff-outcome")
  local _, diff_leaf = root_with_leaf(diff_s)
  handed_over(diff_s, diff_leaf, 7)
  local diff_code, diff_printed = verdict_and_capture(diff_s, diff_leaf,
    "accept", 7, "abc1234", "reviewer-a")
  assert(diff_code == 0, diff_printed)
  assert(diff_printed:find("awaiting merge — land it", 1, true) ~= nil,
    "a diff's outcome is unchanged: " .. diff_printed)
end

-- A reject clears the research handover with the claim, the way it
-- clears a PR: nothing stands, and the item is todo again.
local function test_a_reject_clears_the_research_handover()
  local s = init_state_repo("verdict-result-reject")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0)
  assert(vrd.cmd_verdict(s, leaf, "reject", 0, "", "review-1") == 0)
  local back = check.must(store.load(s, leaf))
  assert(back.result == "" and back.claim == "" and back.verdict == "",
    "nothing stands after a reject")
  assert(state_of(s, back.id) == "todo", "the item is todo again")
end

-- A take never re-opens an accept, on either handover: a moved spec
-- over a standing accept records the new revision and the accept
-- stands, exactly as a new PR number over one does — `verdict` still
-- refuses to re-judge it, and `done` lands it. A send-back is the one
-- verdict a fresh handover clears, on both sides alike.
local function test_a_handover_over_an_accept_keeps_the_accept()
  local s = init_state_repo("verdict-result-accept-moved")
  local _, leaf = root_with_leaf(s)
  give_spec(s, leaf)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0)
  assert(vrd.cmd_verdict(s, leaf, "accept", 0, "", "reviewer-a") == 0)
  local base = fs.join(fixture.tmpdir, "accept-base.md")
  assert(fs.write(base, store.read_spec(s, leaf)))
  local moved = fs.join(fixture.tmpdir, "accept-moved.md")
  assert(fs.write(moved, store.read_spec(s, leaf) .. "\nA late footnote.\n"))
  assert(gitspec.cmd_spec(s, leaf, moved, base, "session-a") == 0)
  assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "", true) == 0,
    "the moved spec is handed over")
  local it = check.must(store.load(s, leaf))
  assert(it.result == spec.revision(store.read_spec(s, leaf)),
    "the new revision is recorded")
  assert(it.verdict == "accept", "and the accept stands")
  assert(vrd.cmd_verdict(s, leaf, "accept", 0, "", "reviewer-b") ~= 0,
    "an accept is landed, never re-judged")
  assert(verbs.cmd_done(s, leaf, "completed", false, "") == 0, "done lands it")
  -- The PR side, for the mirror: a new number over an accept keeps it.
  local _, other = root_with_leaf(s)
  handed_over(s, other, 7)
  assert(vrd.cmd_verdict(s, other, "accept", 7, "cafe1234", "reviewer-a") == 0)
  assert(verbs.cmd_take(s, other, "session-a", 8, false, "") == 0)
  assert(check.must(store.load(s, other)).verdict == "accept",
    "the PR handover leaves an accept standing too")
  -- And a send-back is what a fresh handover clears, on both sides.
  local _, third = root_with_leaf(s)
  give_spec(s, third)
  assert(verbs.cmd_take(s, third, "session-b", 0, false, "") == 0)
  assert(verbs.cmd_take(s, third, "session-b", 0, false, "", true) == 0)
  assert(vrd.cmd_verdict(s, third, "request changes", 0, "", "reviewer-a") == 0)
  assert(verbs.cmd_take(s, third, "session-b", 0, false, "", true) == 0,
    "the same spec re-handed over answers the send-back")
  assert(check.must(store.load(s, third)).verdict == "",
    "and the send-back clears, as `--pr N` again clears it")
end
