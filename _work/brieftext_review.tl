--- The review-role prompts `_work.brief` emits: `REVIEW` judges a
--- builder's handed-over commit the adversarial way, `REVIEW_SCRIPT` judges a
--- mechanical one (no `.tl` file outside `*_test.tl`, or under 20
--- changed lines) with a fixed four-move script instead,
--- research uses the same exact-head review. Split out
--- of `_work.brieftext` so that module has headroom for its
--- non-review templates to grow; the grammar, the context records,
--- and the rendering itself are unchanged — `brief` still resolves
--- the context and picks the PR shape between `REVIEW` and
--- `REVIEW_SCRIPT`, this module only holds the templates' text.
---
--- Pure data: template SOURCE, in `cosmic.template`'s grammar.
--- `_work/brieftmpl_gen.tl` compiles each one into a typed renderer
--- under `_work/brieftmpl/` against `_work.briefctx`'s records, so an
--- interpolation naming a field no record declares fails the build.
--- Text outside `{{ }}` is literal — a spec spliced into `{{.spec}}`
--- is data and is never reinterpreted as template syntax.
---
--- `{{.worktree}}` in `REVIEW` is the review checkout `worktree ID --review`
--- makes — the `wt` directory beside the mapped product checkout, then the
--- claim's own `work/<handle>/<claim-root-short>` branch — filled only
--- once that directory exists. `REVIEW_SCRIPT` is checkout-free: its
--- mutation step uses
--- `git show <head>:<path>` into the scratchpad, and its verdict block
--- reads the diff from `{{.product_root}}` without a `{{.worktree}}`
--- field at all. The shared checkout note still points at
--- `{{.bootstrap_phrase}}` (`_work.brief` resolves it from the item's
--- resolved repo kind via `_work.briefcommands` — the fresh-checkout
--- bootstrap plan in full, never just its last step, plus its own
--- trailing "before you run any test" prose) before a review test
--- runs; `{{.test_cmd_phrase}}` in the mutation-test line is that same
--- module's resolved test-file command, backtick-quoted with its own
--- `<file>`. Both fall back to the exact literal sentence these
--- templates carried before `_work.briefcommands` existed when the
--- resolver cannot place the item's repo.
---
--- `{{.product_root}}` is the reviewer's own local product checkout — where the
--- diff is read and, in `REVIEW_SCRIPT`, the `--repo-dir` the caller passes;
--- `_work.brief` resolves it from the ITEM's own repository through the
--- `gitboard.repository` map, so it names the tree the diff's files live
--- in even when gitboard itself was run from a checkout of another
--- repository, and falls back to that checkout only when the item's repo
--- is not mapped here. It is never the invocation gitboard itself runs
--- through: that is `{{.gitboard_cmd}}`, the caller's own exact loader-plus-
--- executable prefix (`_work.brief` resolves it from a builder's `--receipt`
--- or from `--gitboard-command`/`--gitboard-cwd` given directly to this
--- brief), rendered once and reused before every verb below. Unresolved —
--- no caller command supplied — renders as an explicit sentinel, never a
--- guessed `bin/gitboard` that would strand a fresh reviewer behind a
--- product-checkout network bootstrap. Verdict records the exact
--- handed-over commit and performs no provider or authenticated operation.
---
--- `{{.round_context}}` (`REVIEW` only, between the spec block and "How
--- to review") is where a SECOND (or later) review round's own context
--- goes: the prior request-changes verdict's judged head, the PR's
--- current head, the round count, and that round's own formal review
--- body, rendered from `ROUND` below and spliced in. `_work.brief`
--- resolves it as the same intentionally EMPTY string a fresh, not yet
--- reworked item's `{{.bounce_context}}` gets — an empty value, never
--- an unresolved one, since nothing ever hand-fills this the way an
--- orchestrator might hand-fill a bounce paragraph.

local ROUND < const > = [[
## Round {{.round_number}} context — this is a rework, not a fresh review

Round {{.round_number}} requested changes on head `{{.judged_head}}`; the
PR's head has since moved to `{{.current_head}}`. That round's review,
verbatim:

> {{.round_finding}}

Confirm each finding above is closed — repeat its own reproduction —
then judge the whole diff; what round 1 accepted is settled.
]]

local REVIEW < const > = [[
You are a fresh-context code reviewer for `{{.repo}}`. You have never
seen this change before — that is deliberate: the review must come
from a distance from the builder. Everything you need is below.

## What you're reviewing

Board item id: `{{.item_id}}` (handle {{.handle}})
Title: {{.title}}
{{.change_source}}

The caller has made this exact commit available in your local checkout.
Review `{{.claim_base}}..{{.head_sha}}`; never substitute a branch tip or provider
state for either commit. The spec below is authoritative. External checks,
when used, must be inspected by the caller on this exact SHA.

## The spec this PR is supposed to satisfy (verbatim)

---
{{.spec}}
---

{{.round_context}}
## How to review — the posture is ADVERSARIAL

Your job is to try to make this diff fail, not to confirm it looks
fine.

1. Confirm you are reading exactly `{{.head_sha}}`. If the caller supplies
   external checks, confirm they name that SHA; red or running means stop and
   record nothing. Never infer check state from the board. The caller spawns
   this review only once mechanical checks are green on this exact head (or,
   when CI was unavailable by the item's own design, once the caller ran the
   spec-named guards locally instead) — trust that gate; your job is the
   fresh semantic read and mutation below, not re-verifying CI.
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
test file that guards it ({{.test_cmd_phrase}}), not the suite —
restore it exactly. A real break changes the outcome the test reads,
never just the text around it: replace a matched needle with
unrelated text rather than extending it, flip a boolean rather than
renaming it, and if the test stays green the guard is decoration.
Do this from your own fresh checkout at `{{.worktree}}` — never reuse
another agent's worktree.
The checkout that holds the board worktree (`{{.board_dir}}/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.

## Recording your verdict

`verdict` verifies and records one local commit id. It performs no fetch,
credential lookup, check read, merge, or provider write. The caller owns
those operations. This review is claimed under session `{{.review_session}}` —
you MUST use that exact string. That checkout has no `o/3p` cache yet — run
{{.bootstrap_phrase}}

GitBoard invocation for this review: `{{.gitboard_cmd}}` — the exact
loader and absolute executable the caller runs board commands through.
Use it verbatim as the prefix below; never guess a product-checkout
substitute of your own, and never bootstrap one yourself.

```
{{.gitboard_cmd}} verdict {{.item_id}} accept \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.worktree}}
{{.gitboard_cmd}} verdict {{.item_id}} request-changes \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.worktree}}
{{.gitboard_cmd}} verdict {{.item_id}} reject \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.worktree}}
```

Run exactly the one line matching your judgment. The board stores the SHA,
not review prose. Put concrete gaps in your final report for the caller. An
accept does not merge or complete the item; after landing, the caller runs
`{{.gitboard_cmd}} done {{.item_id}} --landed SHA`.

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
You are a fresh-context code reviewer for `{{.repo}}`. You have never
seen this change before — that is deliberate: the review must come
from a distance from the builder. Everything you need is below.

## What you're reviewing

Board item id: `{{.item_id}}` (handle {{.handle}})
Title: {{.title}}
{{.change_source}}

The caller has made this exact commit available in your local checkout.
The checkout that holds the board worktree (`{{.board_dir}}/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.
Review `{{.claim_base}}..{{.head_sha}}`; never substitute a branch tip or provider
state for either commit. The spec below is authoritative. External checks,
when used, must be inspected by the caller on this exact SHA.

## The spec this PR is supposed to satisfy (verbatim)

---
{{.spec}}
---

## How to review — a numbered script

This diff is mechanical: no changed `.tl` file outside `*_test.tl`,
or fewer than 20 changed lines in total. Four fixed moves, in order:

1. Confirm you are reading exactly `{{.head_sha}}`. If the caller supplies
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
show <head>:<path>` in the product checkout at `{{.product_root}}`; you create
no worktree. This review is claimed under session `{{.review_session}}` — you
MUST use that exact string. That checkout has no `o/3p` cache yet — run
{{.bootstrap_phrase}}

GitBoard invocation for this review: `{{.gitboard_cmd}}` — the exact
loader and absolute executable the caller runs board commands through.
Use it verbatim as the prefix below; never guess a product-checkout
substitute of your own, and never bootstrap one yourself.

```
{{.gitboard_cmd}} verdict {{.item_id}} accept \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.product_root}}
{{.gitboard_cmd}} verdict {{.item_id}} request-changes \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.product_root}}
{{.gitboard_cmd}} verdict {{.item_id}} reject \
  --head {{.head_sha}} --session {{.review_session}} --repo-dir {{.product_root}}
```

Run exactly the one line matching your judgment. The board stores the SHA,
not review prose. Put concrete gaps in your final report for the caller. An
accept does not merge or complete the item; after landing, the caller runs
`{{.gitboard_cmd}} done {{.item_id}} --landed SHA`.

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
