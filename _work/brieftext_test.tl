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
local REWORK < const > = flat(brieftext.REWORK)
local REVIEW < const > = flat(brieftext_review.REVIEW)
local REVIEW_SCRIPT < const > = flat(brieftext_review.REVIEW_SCRIPT)

local function test_builder_requires_a_committed_migration_and_caller_report()
  assert(BUILDER:find(
      "When `## Change` alters a committed tracking file's shape, follow "
      .. "its migration plan and commit the migrated file with the change; "
      .. "name the first-run or one-off bridge, if any, in your final report "
      .. "for the caller's PR body. If the plan is absent, STOP and request "
      .. "refinement before editing the tracking file.", 1, true) ~= nil,
    "the builder must commit migrated rows, report the bridge, or stop for refinement")
end

local function test_step_one_measures_headroom_before_the_first_edit()
  assert(BUILDER:find(
      "Before the first edit, `wc -l` every file the Change names.",
      1, true) ~= nil,
    "step 1 must tell a builder to measure headroom before editing")
end

local function test_step_one_offers_a_split_seam_before_an_unconditional_stop()
  assert(BUILDER:find(
      "A file at or within a few lines of the repo's own file-length "
      .. "cap — check its `AGENTS.md` (or equivalent) for the number, "
      .. "the same convention gitboard already defers to everywhere "
      .. "else — is not an automatic STOP: if it has an obvious, "
      .. "low-risk split seam (a self-contained group of test cases, "
      .. "a section already separated by a comment header) and the "
      .. "spec's Non-goals don't forbid touching the file's shape, "
      .. "split it and land the new coverage in the new sibling file "
      .. "— name the split explicitly in the PR body as a deviation "
      .. "from the literal file list.", 1, true) ~= nil,
    "step 1 must offer a low-risk split-seam path — new coverage in a "
    .. "sibling file, named as a deviation in the PR body — before an "
    .. "unconditional STOP")
  assert(BUILDER:find(
      "If no safe seam is obvious, or the split itself would be a "
      .. "judgment call bigger than the item's own scope, STOP now "
      .. "(report the count) rather than after implementing — this "
      .. "remains the right answer for a genuinely ambiguous split.",
      1, true) ~= nil,
    "step 1 must still STOP, reporting the count, when no safe split "
    .. "seam is obvious or the split is itself too big a judgment call")
end

-- The old wording asserted cosmic's own 500-line cap as if it were a
-- gitboard invariant. A fixture repo whose own convention states a
-- different number (Acme's `AGENTS.md` here caps files at 300 lines,
-- not 500) proves the reworded step 1 no longer bakes in any specific
-- repo's cap: it names no number at all, and instead points a builder
-- at whatever the target repo's own `AGENTS.md` (or equivalent) states.
local function test_step_one_defers_to_the_repos_own_file_length_convention()
  local ACME_AGENTS_MD < const > = [[
# AGENTS.md

- file length: <=300 lines, no exceptions, enforced by `make lint`
]]
  assert(ACME_AGENTS_MD:find("300", 1, true) ~= nil
    and ACME_AGENTS_MD:find("500", 1, true) == nil,
    "the fixture repo must state a cap other than cosmic's 500")

  assert(BUILDER:find("500", 1, true) == nil,
    "step 1 must not hardcode any specific repo's line-count number, "
    .. "cosmic's 500 included — Acme's fixture states 300 instead")
  assert(BUILDER:find(
      "check its `AGENTS.md` (or equivalent) for the number, "
      .. "the same convention gitboard already defers to everywhere "
      .. "else", 1, true) ~= nil,
    "step 1 must defer to the repo's own AGENTS.md (or equivalent) "
    .. "for the file-length cap, the same way every other repo "
    .. "convention is already treated")
end

local function test_step_three_prefers_a_per_file_check_between_edits()
  assert(BUILDER:find(
      "Between edits, <TYPE_CHECK_CMD> on the files "
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

local function test_step_seven_leaves_authenticated_operations_to_the_caller()
  assert(BUILDER:find(
      "The caller owns every authenticated operation: do not push or "
      .. "open an external review unless it explicitly asks you to.",
      1, true) ~= nil,
    "step 7 leaves pushes and provider interactions with the caller")
end

local function test_the_builder_hands_over_a_commit_id()
  assert(BUILDER:find("create_pull_request", 1, true) == nil,
    "the builder brief must not send a builder to a provider API")
  assert(BUILDER:find("<GITBOARD_CMD> take <ITEM_ID> --head SHA [--url URL]",
      1, true) ~= nil,
    "the builder reports the commit-only handover command, prefixed with "
    .. "the caller's own exact GitBoard invocation")
end

-- `verdict` performs only local Git verification and a board mutation.
local function test_the_review_brief_records_only_the_commit()
  assert(REVIEW:find("mcp__github", 1, true) == nil,
    "the review brief must name no provider MCP tool")
  assert(REVIEW:find("enable_pr_auto_merge", 1, true) == nil
    and REVIEW:find("enable auto-merge", 1, true) == nil,
    "the review brief must not instruct a reviewer to enable auto-merge "
    .. "itself")
  assert(REVIEW:find("<GITBOARD_CMD> verdict <ITEM_ID> accept", 1, true) ~= nil,
    "the accept line runs the caller's own GitBoard invocation, not a "
    .. "guessed bin/gitboard")
  assert(REVIEW:find(
      "<GITBOARD_CMD> verdict <ITEM_ID> request-changes", 1, true)
    ~= nil, "request-changes records the same commit id")
  assert(REVIEW:find("--body FILE", 1, true) == nil
    and REVIEW:find("--pr", 1, true) == nil,
    "review prose and provider ids are not board evidence")
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
      "If the caller supplies external checks, confirm they name that SHA; "
      .. "red or running means stop and record nothing. Never infer check "
      .. "state from the board.", 1, true) ~= nil,
    "step 1 keeps external check inspection caller-owned and SHA-bound")
end

local function test_step_two_reruns_find_against_the_handover()
  assert(REVIEW:find(
      "When the spec states a pattern and a count, re-run "
      .. "`cosmic --find` on the handed-over commit from your checkout: the hit "
      .. "list IS the expected change set — a hit the diff leaves "
      .. "unchanged, or a changed site outside the hits, is a "
      .. "finding.", 1, true) ~= nil,
    "step 2 must send a reviewer to re-run cosmic --find on the exact "
    .. "handover when the spec states a pattern and a count")
end

local function test_mutation_step_names_the_one_file_shape()
  assert(REVIEW:find(
      "run the ONE test file that guards it (<TEST_CMD_PHRASE>), "
      .. "not the suite", 1, true) ~= nil,
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
      .. "a new test moves a row's `total`; run `<BOOTSTRAP_CMD>` once "
      .. "before `--check types` on a file whose sibling you moved.",
      1, true) ~= nil,
    "step 3 must say to run --make coverage after the last test edit, "
    .. "not before, and the resolved bootstrap command once before "
    .. "--check types on a file whose sibling moved")
end

-- The numbered-script review's mutation move is checkout-free — a
-- copy of the guarded file taken with `git show <head>:<path>`, never
-- a fresh checkout `REVIEW`'s own mutation paragraph sends a reviewer
-- to make.
local function test_the_review_script_mutates_a_git_show_copy()
  assert(REVIEW_SCRIPT:find("git show", 1, true) ~= nil,
    "the script template must name git show as its mutation source")
  assert(REVIEW_SCRIPT:find("fresh checkout", 1, true) == nil,
    "the script template must never send a reviewer to a fresh checkout")
end

local function test_the_review_script_verdict_is_checkout_free()
  assert(REVIEW_SCRIPT:find("own checkout", 1, true) == nil,
    "the script verdict must not send a reviewer to an own checkout")
  assert(REVIEW_SCRIPT:find("<WORKTREE>", 1, true) == nil,
    "the script template must not contain a worktree placeholder")
  assert(REVIEW_SCRIPT:find("git show", 1, true) ~= nil
    and REVIEW_SCRIPT:find("product checkout", 1, true) ~= nil,
    "the script verdict must name the product checkout and git show")
  assert(REVIEW:find("fresh checkout", 1, true) ~= nil,
    "the full review must retain its own checkout wording")
  assert(REVIEW:find("<WORKTREE>", 1, true) ~= nil,
    "the full review must retain its worktree placeholder")
end

-- A freshly made review checkout has no `o/3p` cache — the same gap
-- `worktree ID` already closes for a builder — so both review
-- templates must send a reviewer to `--make fetch` (and, for any
-- test, `--make build`) before that checkout's first test runs.
local function test_the_checkout_note_sends_a_reviewer_to_fetch_first()
  for _, tmpl in ipairs({REVIEW, REVIEW_SCRIPT}) do
    assert(tmpl:find(
        "That checkout has no `o/3p` cache yet — run "
        .. "<BOOTSTRAP_PHRASE>", 1, true) ~= nil,
      "the checkout note must send a reviewer to the resolved bootstrap "
      .. "plan before running any test: " .. tmpl)
  end
end

local function test_step_five_says_to_commit_before_mutating()
  assert(BUILDER:find(
      "Commit the real change before mutation-testing it, so a "
      .. "checkout-restore used to undo the mutation cannot wipe it "
      .. "too.", 1, true) ~= nil,
    "step 5 must say to commit the real change before "
    .. "mutation-testing it, so a checkout-restore cannot wipe it")
end

-- The orchestrator recovers a stalled build by working directly in the
-- builder's own worktree, so a builder that meets foreign history there
-- must neither investigate it as a broken environment nor undo it.
-- The correction the rework builder hands back is a NEW head; the
-- judged commit's own verification does not transfer to it.
local function test_rework_states_a_new_head_invalidates_prior_evidence()
  assert(REWORK:find(
      "Every correction produces a NEW candidate head, and a new head "
      .. "invalidates every prior verification:", 1, true) ~= nil,
    "the rework brief must state that every correction creates a new "
    .. "head and invalidates prior verification evidence")
  assert(REWORK:find(
      "Never carry one forward with a claim like "
      .. "\"the prior cold-build remains green\" once the head has "
      .. "moved,", 1, true) ~= nil,
    "the rework brief must forbid carrying forward a stale claim like "
    .. "\"the prior cold-build remains green\" for a new head")
end

local function test_rework_requires_a_diff_against_the_judged_head()
  assert(REWORK:find(
      "diff the rejected head against the new head (`git diff "
      .. "<JUDGED_HEAD> <new head>`) and name, in your final report, "
      .. "the boundaries the correction crosses", 1, true) ~= nil,
    "the rework brief must require diffing the rejected head against "
    .. "the new head and naming the boundaries the correction crosses")
end

local function test_rework_requires_the_spec_named_guards_rerun()
  assert(REWORK:find(
      "rerun every acceptance/guard command the item spec names "
      .. "explicitly, even when the correction looks unrelated to "
      .. "what that command checks.", 1, true) ~= nil,
    "the rework brief must require rerunning every spec-named "
    .. "acceptance/guard command, even one that looks unrelated")
  assert(REWORK:find(
      "This is not a license to rerun `--make ci` (or the target "
      .. "repo's own gate) on every rework: keep reaching for the one "
      .. "focused guard", 1, true) ~= nil,
    "the rework brief must still prefer a focused guard over a "
    .. "repeated broad gate")
end

local function test_where_to_work_warns_the_worktree_is_shared()
  assert(BUILDER:find(
      "The worktree is yours to work in, but not yours alone: while "
      .. "your turn is between tool calls the orchestrator may run "
      .. "commands in it, edit files, commit, and push — most often to "
      .. "finish a build you left waiting on a background command.",
      1, true) ~= nil,
    "Where to work must say the orchestrator may work directly in the "
    .. "builder's own worktree between its turns")
  assert(BUILDER:find(
      "Never investigate one as an environment bug, and never undo it "
      .. "— no `git reset --hard`, no `git revert`, no force-push.",
      1, true) ~= nil,
    "Where to work must forbid investigating or undoing a change in "
    .. "the worktree the builder did not make")
end

-- The bounce that motivated this guidance found a real bug but let the
-- rework builder pick its own repair, which crossed a pinned-checker
-- boundary and cost a second review round. A request-changes verdict
-- must instead name the tempting unsafe fix and the invariant it
-- risks, so the rework builder bounces on an unclear envelope rather
-- than widening scope to find one.
local function test_request_changes_names_five_labeled_facts()
  for _, tmpl in ipairs({REVIEW, REVIEW_SCRIPT}) do
    assert(tmpl:find(
        "A request-changes verdict names five labeled facts, not a "
        .. "fix: the exact reproducer; the smallest permitted "
        .. "correction boundary; the tempting unsafe repair, when "
        .. "one is visible; the adjacent invariant that repair could "
        .. "violate; and the focused regression plus every named "
        .. "boundary guard the corrected head must rerun.", 1, true)
      ~= nil,
      "request-changes guidance must name all five labeled facts: " .. tmpl)
  end
end

local function test_request_changes_forbids_designing_the_correction()
  for _, tmpl in ipairs({REVIEW, REVIEW_SCRIPT}) do
    assert(tmpl:find(
        "Do not design the correction: when no safe envelope is "
        .. "established, name the uncertainty and let the rework "
        .. "builder bounce rather than widening scope to find one.",
        1, true) ~= nil,
      "request-changes guidance must forbid designing the correction "
      .. "and instead tell the reviewer to name the uncertainty: " .. tmpl)
  end
end
