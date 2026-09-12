--- The review-role prompts `_work.brief` emits: `REVIEW` judges a
--- builder's handed-over commit the adversarial way, `REVIEW_SCRIPT` judges a
--- mechanical one (no `.tl` file outside `*_test.tl`, or under 20
--- changed lines) with a fixed four-move script instead,
--- research uses the same exact-head review. Split out
--- of `_work.brieftext` so that module has headroom for its
--- non-review templates to grow; the fill grammar, the placeholder
--- rules, and the filling itself are unchanged — `brief` still does
--- the filling and the PR-shape selection between `REVIEW` and
--- `REVIEW_SCRIPT`, this module only holds the templates' text.
---
--- Pure data. The fill grammar is `<UPPER_SNAKE>`; anything else in
--- angle brackets is prose and must not match that shape.
---
--- `<WORKTREE>` in `REVIEW` is the review checkout `worktree ID --review`
--- makes — the `wt` directory beside the mapped product checkout, then the
--- claim's own `work/<handle>/<claim-root-short>` branch — filled only
--- once that directory exists. `REVIEW_SCRIPT` is checkout-free: its
--- mutation step uses
--- `git show <head>:<path>` into the scratchpad, and its verdict block
--- reads the diff from `<PRODUCT_ROOT>` without a `<WORKTREE>`
--- placeholder. The shared checkout note still points at
--- `<BOOTSTRAP_PHRASE>` (`_work.brief` fills it from the item's
--- resolved repo kind via `_work.briefcommands` — the fresh-checkout
--- bootstrap plan in full, never just its last step, plus its own
--- trailing "before you run any test" prose) before a review test
--- runs; `<TEST_CMD_PHRASE>` in the mutation-test line is that same
--- module's resolved test-file command, backtick-quoted with its own
--- `<file>`. Both fall back to the exact literal sentence these
--- templates carried before `_work.briefcommands` existed when the
--- resolver cannot place the item's repo.
---
--- `<PRODUCT_ROOT>` is the reviewer's own local product checkout — where the
--- diff is read and, in `REVIEW_SCRIPT`, the `--repo-dir` the caller passes;
--- `_work.brief` derives it from the `GITBOARD_DIR` it was run under (its
--- parent's parent). It is never the invocation gitboard itself runs
--- through: that is `<GITBOARD_CMD>`, the caller's own exact loader-plus-
--- executable prefix (`_work.brief` fills it from a builder's `--receipt`
--- or from `--gitboard-command`/`--gitboard-cwd` given directly to this
--- brief), rendered once and reused before every verb below. Unresolved —
--- no caller command supplied — renders as an explicit sentinel, never a
--- guessed `bin/gitboard` that would strand a fresh reviewer behind a
--- product-checkout network bootstrap. Verdict records the exact
--- handed-over commit and performs no provider or authenticated operation.
---
--- `<ROUND_CONTEXT>` (`REVIEW` only, between the spec block and "How
--- to review") is `_work.brief`'s fill for a SECOND (or later) review
--- round: the prior request-changes verdict's judged head, the PR's
--- current head, the round count, and that round's own formal review
--- body, spliced from `ROUND` below — always the same "" a fresh, not
--- yet reworked item's `<BOUNCE_CONTEXT>` fills, but rendered as an
--- actual empty string rather than left as literal placeholder text,
--- since nothing ever hand-fills this one the way an orchestrator
--- might hand-fill a bounce paragraph.

local ROUND < const > = [[
## Round <ROUND_NUMBER> context — this is a rework, not a fresh review

Round <ROUND_NUMBER> requested changes on head `<JUDGED_HEAD>`; the
PR's head has since moved to `<CURRENT_HEAD>`. That round's review,
verbatim:

> <ROUND_FINDING>

Confirm each finding above is closed — repeat its own reproduction —
then judge the whole diff; what round 1 accepted is settled.
]]

local REVIEW < const > = [[
You are a fresh-context code reviewer for `<REPO>`. You have never
seen this change before — that is deliberate: the review must come
from a distance from the builder. Everything you need is below.

## What you're reviewing

Board item id: `<ITEM_ID>` (handle <HANDLE>)
Title: <TITLE>
<CHANGE_SOURCE>

The caller has made this exact commit available in your local checkout.
Review `<CLAIM_BASE>..<HEAD_SHA>`; never substitute a branch tip or provider
state for either commit. The spec below is authoritative. External checks,
when used, must be inspected by the caller on this exact SHA.

## The spec this PR is supposed to satisfy (verbatim)

---
<SPEC>
---

<ROUND_CONTEXT>
## How to review — the posture is ADVERSARIAL

Your job is to try to make this diff fail, not to confirm it looks
fine.

1. Confirm you are reading exactly `<HEAD_SHA>`. If the caller supplies
   external checks, confirm they name that SHA; red or running means stop and
   record nothing. Never infer check state from the board.
2. The diff is the Change — everything present, nothing extra. List
   the changed files and confirm each is inside the spec's stated
   scope. Anything outside it is scope creep — quote it, even when
   it looks good; good ideas become their own items. When the spec
   states a pattern and a count, re-run `cosmic --find` on the handed-over
   commit from your checkout: the hit list IS the expected change
   set — a hit the diff leaves unchanged, or a changed site outside
   the hits, is a finding.
3. The walls held: every `## Non-goals` line honored, frozen
   contracts unmoved.
4. Conventions hold: the repo's AGENTS.md binds. Anything a gate
   should have caught but did not is itself a finding to report.
5. It serves the outcome: judge the diff against the item's parent
   chain, not just the letter of `## Change`. A green gate on a
   change that misses the point means the SPEC was wrong — say so,
   never wave the diff through.
6. It is the least thing: name any surplus concretely and treat it
   as a gap to quote.

Mutation-test at least one guard the change adds or relies on: break
what it guards, confirm the diff's own test catches it — run the ONE
test file that guards it (<TEST_CMD_PHRASE>), not the suite —
restore it exactly. A real break changes the outcome the test reads,
never just the text around it: replace a matched needle with
unrelated text rather than extending it, flip a boolean rather than
renaming it, and if the test stays green the guard is decoration.
Do this from your own fresh checkout at `<WORKTREE>` — never reuse
another agent's worktree.
The checkout that holds the board worktree (`<BOARD_DIR>/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.

## Recording your verdict

`verdict` verifies and records one local commit id. It performs no fetch,
credential lookup, check read, merge, or provider write. The caller owns
those operations. This review is claimed under session `<REVIEW_SESSION>` —
you MUST use that exact string. That checkout has no `o/3p` cache yet — run
<BOOTSTRAP_PHRASE>

GitBoard invocation for this review: `<GITBOARD_CMD>` — the exact
loader and absolute executable the caller runs board commands through.
Use it verbatim as the prefix below; never guess a product-checkout
substitute of your own, and never bootstrap one yourself.

```
<GITBOARD_CMD> verdict <ITEM_ID> accept \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <WORKTREE>
<GITBOARD_CMD> verdict <ITEM_ID> request-changes \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <WORKTREE>
<GITBOARD_CMD> verdict <ITEM_ID> reject \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <WORKTREE>
```

Run exactly the one line matching your judgment. The board stores the SHA,
not review prose. Put concrete gaps in your final report for the caller. An
accept does not merge or complete the item; after landing, the caller runs
`<GITBOARD_CMD> done <ITEM_ID> --landed SHA`.

## Final report

The verdict you recorded (or why you could not), the mutation-test
you ran and its result, and any concrete findings quoted with
file:line. Keep it factual and concise.

A request-changes verdict names five labeled facts, not a fix: the
exact reproducer; the smallest permitted correction boundary; the
tempting unsafe repair, when one is visible; the adjacent invariant
that repair could violate; and the focused regression plus every
named boundary guard the corrected head must rerun. Do not design
the correction: when no safe envelope is established, name the
uncertainty and let the rework builder bounce rather than widening
scope to find one.
]]

local REVIEW_SCRIPT < const > = [[
You are a fresh-context code reviewer for `<REPO>`. You have never
seen this change before — that is deliberate: the review must come
from a distance from the builder. Everything you need is below.

## What you're reviewing

Board item id: `<ITEM_ID>` (handle <HANDLE>)
Title: <TITLE>
<CHANGE_SOURCE>

The caller has made this exact commit available in your local checkout.
The checkout that holds the board worktree (`<BOARD_DIR>/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.
Review `<CLAIM_BASE>..<HEAD_SHA>`; never substitute a branch tip or provider
state for either commit. The spec below is authoritative. External checks,
when used, must be inspected by the caller on this exact SHA.

## The spec this PR is supposed to satisfy (verbatim)

---
<SPEC>
---

## How to review — a numbered script

This diff is mechanical: no changed `.tl` file outside `*_test.tl`,
or fewer than 20 changed lines in total. Four fixed moves, in order:

1. Confirm you are reading exactly `<HEAD_SHA>`. If the caller supplies
   external checks, confirm they name that SHA; red or running means stop and
   record nothing. Never infer check state from the board.
2. Verify the one measured fact the spec names, against the diff's
   real effect. A moved number is a finding to quote, not by itself
   a reason to stop.
3. Break the guard in a scratch copy: `git show <head>:<file>` the
   file the diff's own test guards into the scratchpad, mutate the
   copy (replace a matched needle with unrelated text, flip a
   boolean — never just reword the text around it), run the diff's
   own test file against the mutated copy, and watch it refuse.
4. Record your verdict.

Mutation-test at least one guard the change adds or preserves: break
the guard in a copy of the file taken with `git show <head>:<path>`,
never in a worktree, and confirm the refusal.

## Recording your verdict

`verdict` verifies and records one local commit id. It performs no fetch,
credential lookup, check read, merge, or provider write. The caller owns
those operations. Read the diff with `git fetch origin <branch>` and `git
show <head>:<path>` in the product checkout at `<PRODUCT_ROOT>`; you create
no worktree. This review is claimed under session `<REVIEW_SESSION>` — you
MUST use that exact string. That checkout has no `o/3p` cache yet — run
<BOOTSTRAP_PHRASE>

GitBoard invocation for this review: `<GITBOARD_CMD>` — the exact
loader and absolute executable the caller runs board commands through.
Use it verbatim as the prefix below; never guess a product-checkout
substitute of your own, and never bootstrap one yourself.

```
<GITBOARD_CMD> verdict <ITEM_ID> accept \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <PRODUCT_ROOT>
<GITBOARD_CMD> verdict <ITEM_ID> request-changes \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <PRODUCT_ROOT>
<GITBOARD_CMD> verdict <ITEM_ID> reject \
  --head <HEAD_SHA> --session <REVIEW_SESSION> --repo-dir <PRODUCT_ROOT>
```

Run exactly the one line matching your judgment. The board stores the SHA,
not review prose. Put concrete gaps in your final report for the caller. An
accept does not merge or complete the item; after landing, the caller runs
`<GITBOARD_CMD> done <ITEM_ID> --landed SHA`.

## Final report

The verdict you recorded (or why you could not), the mutation-test
you ran and its result, and any concrete findings quoted with
file:line. Keep it factual and concise.

A request-changes verdict names five labeled facts, not a fix: the
exact reproducer; the smallest permitted correction boundary; the
tempting unsafe repair, when one is visible; the adjacent invariant
that repair could violate; and the focused regression plus every
named boundary guard the corrected head must rerun. Do not design
the correction: when no safe envelope is established, name the
uncertainty and let the rework builder bounce rather than widening
scope to find one.
]]

local record brieftext_review
  REVIEW: string
  REVIEW_SCRIPT: string
  ROUND: string
end

local M: brieftext_review = {
  REVIEW = REVIEW,
  REVIEW_SCRIPT = REVIEW_SCRIPT,
  ROUND = ROUND,
}

return M
