#!/usr/bin/env cosmic
-- The builder brief's own text carries the practices a builder must
-- follow before `brief` ever fills a placeholder — pin each one by a
-- literal find, the way `_work.review_test` pins the `Board:` line.
-- The template hand-wraps its prose across lines, so a pinned sentence
-- is matched against a whitespace-flattened copy rather than raw text
-- — a rewrap must not itself break these tests.

local brieftext = require("_work.brieftext")
local brieftext_review = require("_work.brieftext_review")

--- `s` with every run of whitespace (including the template's own
--- line wraps) collapsed to one space, so a sentence pinned here reads
--- the same whether the template wraps it across one line or several.
--- @param s string The text to flatten
--- @return string The flattened text
local function flat(s: string): string
  return (s:gsub("%s+", " "))
end

local BUILDER < const > = flat(brieftext.BUILDER)
local REVIEW < const > = flat(brieftext_review.REVIEW)

local function test_step_one_measures_headroom_before_the_first_edit()
  assert(BUILDER:find(
      "Before the first edit, `wc -l` every file the Change names; if "
      .. "the Change's additions cannot fit under the 500-line cap, "
      .. "STOP now (report the count) rather than after implementing.",
      1, true) ~= nil,
    "step 1 must tell a builder to measure headroom before editing "
    .. "and stop before implementing, not after")
end

local function test_step_three_prefers_a_per_file_check_between_edits()
  assert(BUILDER:find(
      "Between edits, `bin/cosmic --check types <file>` on the files "
      .. "you touched; run the full gate once, before the push.",
      1, true) ~= nil,
    "step 3 must prefer a per-file check between edits and reserve "
    .. "the full gate for once, before the push")
end

local function test_the_stop_rule_keeps_the_diff_on_a_bounce()
  assert(BUILDER:find(
      "Leave your diff committed on the item branch (unpushed), never "
      .. "reverted: the respec starts from it.", 1, true) ~= nil,
    "the STOP rule must say to keep the diff on the item branch, "
    .. "unpushed, never reverted")
end

local function test_step_seven_reports_a_base_conflict_rather_than_rebasing()
  assert(BUILDER:find(
      "If the push or the PR shows a conflict with the base branch, "
      .. "stop and report it with the conflicting files; merging the "
      .. "base into the item branch is the orchestrator's, never a "
      .. "builder's rebase.", 1, true) ~= nil,
    "step 7 must tell a builder to stop and report a base conflict, "
    .. "never rebase it themselves")
end

local function test_the_builder_never_opens_its_own_pr()
  assert(BUILDER:find("create_pull_request", 1, true) == nil,
    "the builder brief must not send a builder to open its own PR — "
    .. "that reach is the orchestrator's, through `gitboard take ID "
    .. "--open`")
  assert(BUILDER:find("take ID --open", 1, true) ~= nil,
    "the builder's Open a PR step must hand the PR off to "
    .. "`gitboard take ID --open` instead of opening one itself")
end

-- `verdict` performs the GitHub side of a review itself, so the
-- review brief must send a reviewer to no GitHub tool of its own —
-- neither the `gh` CLI nor an MCP tool, and no "enable auto-merge"
-- instruction, since `bin/gitboard verdict` is now the one command.
local function test_the_review_brief_touches_no_github_tool_itself()
  assert(REVIEW:find("mcp__github", 1, true) == nil,
    "the review brief must name no GitHub MCP tool — `verdict` performs "
    .. "the write itself")
  assert(REVIEW:find("enable_pr_auto_merge", 1, true) == nil
    and REVIEW:find("enable auto-merge", 1, true) == nil,
    "the review brief must not instruct a reviewer to enable auto-merge "
    .. "itself")
  assert(REVIEW:find("bin/gitboard verdict <ITEM_ID> accept", 1, true) ~= nil,
    "the accept line runs `gitboard verdict` directly")
  assert(REVIEW:find(
      "bin/gitboard verdict <ITEM_ID> request-changes --body FILE", 1, true)
    ~= nil, "the request-changes line requires --body FILE")
  assert(REVIEW:find("bin/gitboard verdict <ITEM_ID> reject --body FILE",
      1, true) ~= nil, "the reject line requires --body FILE")
end

local function test_mutation_step_says_what_a_real_break_is()
  assert(BUILDER:find("replace a matched needle", 1, true) ~= nil,
    "the builder brief's mutation step must say a real break replaces "
    .. "a matched needle with unrelated text, not just extends it")
  assert(REVIEW:find("replace a matched needle", 1, true) ~= nil,
    "the review brief's mutation sentence must say a real break "
    .. "replaces a matched needle with unrelated text, not just "
    .. "extends it")
end

local function test_step_three_names_the_ratchet_recovery_path()
  assert(BUILDER:find(
      "the failure line names its "
      .. "own fix — run that regen or make that edit, then re-run "
      .. "only that test file", 1, true) ~= nil,
    "step 3 must send a builder back to re-run only the tripped "
    .. "ratchet's own test file, not the full gate")
  assert(BUILDER:find(
      "A ratchet row you add is part of the diff, not scope "
      .. "creep: say so in the PR body.", 1, true) ~= nil,
    "step 3 must say an added ratchet row belongs in the PR body, "
    .. "not scope creep")
end

local function test_step_one_bars_a_reviewer_from_rerunning_ci()
  assert(REVIEW:find(
      "Green means the gate ran on this exact head — never re-run "
      .. "`--make ci` or the full test stage yourself; the checks you "
      .. "run are the ones the diff's own test file and your mutation "
      .. "need.", 1, true) ~= nil,
    "step 1 must tell a reviewer never to re-run --make ci or the "
    .. "full test stage on a green head")
end

local function test_mutation_step_names_the_one_file_shape()
  assert(REVIEW:find(
      "run the ONE test file that guards it (`bin/cosmic --make test "
      .. "<file>` in cosmic, `bin/cosmic --make test _work/<file>` in "
      .. "work), not the suite", 1, true) ~= nil,
    "the mutation paragraph must send a reviewer to the diff's own "
    .. "test file, not the suite")
end

local function test_step_three_names_the_new_module_ratchets()
  assert(BUILDER:find(
      "A new public `cosmic.<name>` module trips three more: "
      .. "`_build/public_surface_baseline.tl` (`--make run "
      .. "_build/public_surface.tl --baseline`), the example ratchet "
      .. "(a runnable `<name>/init_example.tl` or `<name>_example.tl`), "
      .. "and `_build/doc_returns_test` (one `@return` tag per declared "
      .. "slot on every function it exports).", 1, true) ~= nil,
    "step 3 must name the three ratchets a new public cosmic.<name> "
    .. "module trips: public_surface_baseline, the example ratchet, "
    .. "and doc_returns_test")
end

local function test_step_three_orders_coverage_after_the_last_test_edit()
  assert(BUILDER:find(
      "Run `--make coverage` after your last test edit, not before — "
      .. "a new test moves a row's `total`; run `--make build` once "
      .. "before `--check types` on a file whose sibling you moved.",
      1, true) ~= nil,
    "step 3 must say to run --make coverage after the last test edit, "
    .. "not before, and --make build once before --check types on a "
    .. "file whose sibling moved")
end

local function test_step_five_says_to_commit_before_mutating()
  assert(BUILDER:find(
      "Commit the real change before mutation-testing it, so a "
      .. "checkout-restore used to undo the mutation cannot wipe it "
      .. "too.", 1, true) ~= nil,
    "step 5 must say to commit the real change before "
    .. "mutation-testing it, so a checkout-restore cannot wipe it")
end
