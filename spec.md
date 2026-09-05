# friction: 2026-09-05 work9 (/work 9 --routine)

## orchestrator
- goal: reconcile the wave per `orchestrate` step 1-2 before spawning anything.
  actually happened: `show` at pass start listed «1Lhz_38Wt» as `state: review`
  with `reviewer: review-1Lhz_38Wt-2305d922` already named. I spent a `pull_request_read`
  agent call plus a `brief review` call and a `take` attempt (refused: "claimed by
  build-1Lhz_38Wt-2305d922 — take over a live claim with --force --why") investigating
  whether that review claim was stale before discovering — only after re-running `sync`
  and `show` again — that a concurrent orchestrator session (`2305d922`) had *already*
  recorded `verdict ... accept` and moved the item to `state: accepted` while I was
  mid-investigation. ~3 extra tool calls (1 subagent, 1 brief, 1 failed take) spent on
  now-moot staleness analysis.
  contributed: `show`'s snapshot at pass start was already behind a concurrent
  session's progress by the time I acted on it; nothing in the refusal message
  ("live claim") distinguishes "stale, re-sync" from "another session is finishing
  right now, re-sync in a few seconds."
  improvement: before spending effort judging whether a live claim is stale,
  re-run `sync && show ID` once — cheap — and only then treat the refusal as
  a real conflict. Doc-level fix, not a gate.
- goal: land «1Lhz_38Wt»'s accept via auto-merge per `help review`'s accept step.
  actually happened: `enable_pr_auto_merge` on cosmic-lua/cosmic#1727 returned success
  ("Auto-merge enabled ... will merge once required checks pass") but the PR was
  already fully green (`mergeable_state: clean`, all 5 check runs success) *before*
  auto-merge was enabled, and two follow-up `pull_request_read` polls (~15s apart)
  still showed `merged: false`. GitHub's auto-merge apparently does not retroactively
  fire for a PR whose checks completed before auto-merge was turned on; it seems to
  need a new check-suite event to re-evaluate.
  contributed: nothing in `help review`'s accept instructions flags this
  already-green case or gives a fallback.
  improvement: candidate countermeasure — `help review`'s accept step should note
  that an already-green PR's auto-merge may need a nudge (e.g. re-running enable,
  or the orchestrator polling once more before assuming it will fire) rather than
  assuming enable_pr_auto_merge always merges promptly.

- goal: fill the wave per orchestrate step 4 (builds up to disjoint pullable
  work) after the accept/merge/done cycle for «1Lhz_38Wt» completed.
  actually happened: board-level `show` reported `todo 203 (0 pullable)` and
  `next` recommended `refine «vCsZ_TzIP»` (a different item) even AFTER a fresh
  `sync`, immediately following `done 1Lhz_38Wt`. `show q0zL_uDdq` (one of the
  two items `1Lhz_38Wt` had just unblocked, confirmed via `git ls-tree -r` on
  its `edges/blocked_by/` entries) printed no `bar:` failure line and no
  blocker line, so I tried `take q0zL_uDdq` directly as a probe — it
  succeeded immediately ("3IYMP66h is yours"), contradicting both the "0
  pullable" count and `next`'s suggestion. ~6 extra tool calls (a
  `git ls-tree` blocker sweep across all 205 item refs, several `show` calls,
  one exploratory `take`) spent resolving the discrepancy before proceeding.
  contributed: unclear — possibly `next`'s and the board-summary's pullable
  computation cache the graph on a freshness window like `sync`'s own
  "lanes: skipped (observed Ns ago, within the 900s freshness window)"
  behavior, so a blocker cleared by a `done` moments earlier isn't reflected
  in the SAME session's next `show`/`next` call even after `sync` reports
  "state is current" — `take`, by contrast, appears to check fresh. Not
  confirmed against gitboard's own source, so held here rather than filed.
  improvement: candidate countermeasure — when `next`/`show`'s pullable count
  disagrees with a `take` probe on an item the orchestrator has independent
  reason to think just unblocked (e.g. it was named in the resolving item's
  own `unblocks: N open item(s)` line), trust `take`'s live answer over the
  summary and proceed; and/or gitboard should invalidate any pullable-count
  cache on the same mutation that clears a blocker, not just on a time
  window. Needs a repro from someone with `gitboard` source access to
  confirm before filing as a firm item.
- discovered while acting on `next`'s refine suggestion for «vCsZ_TzIP»
  (the item is unchanged from the prior pass: it is a pure human-action wall
  — "no session in this environment has cross-org GitHub access" to file an
  issue against `teal-language/tl` — already filed with full evidence and
  already blocking `FePr_L4FB`). Refining it again would not add information;
  I moved past it to the next bar-failing item («EAi9_RFmX») instead of
  spending a refine slot re-deriving the same wall. Flagging in case a future
  pass should treat "next names a wall this environment already can't cross"
  as its own recognized case (skip without re-deriving) rather than always
  literally acting on `next`'s single suggestion.

## build q0zL_uDdq (background) — first attempt STOPPED short, respec'd, re-spawned
- claimed as `build-q0zL_uDdq-eceb7aa0`, branch `3IYMP66h`, worktree
  `/home/user/wt-q0zL_uDdq`. Before spawning, the orchestrator itself had to
  re-scope the item's spec (`spec` verb, compare-and-swap against the
  original 8-site text) from 8 dynamic-name-lookup sites down to 7: the 8th
  site (`cosmic/searcher_test.tl`) was resolved by a sibling item
  (`1Lhz_38Wt`, just merged) into a narrower patch-only landing that defers
  the cast removal to a THIRD item (`zs1K_cWnY`, blocked on a release + pin
  bump). The original `q0zL_uDdq` spec still told a builder to touch
  `cosmic/searcher_test.tl` and zero the whole cast-sites.tsv class, which
  would have duplicated `zs1K_cWnY`'s scope and likely hit the exact
  cold-build failure `1Lhz_38Wt`'s own evidence already proved. Caught before
  spawning a builder rather than by a builder rediscovering it, but it took
  reading `zs1K_cWnY`'s full spec, re-verifying line counts/site lists
  against current `origin/main`, and a full spec rewrite (~15 tool calls) to
  catch. Countermeasure candidate: when an item's `blocked_by` clears because
  the blocker was RE-SCOPED (not built as originally specced), the blocker's
  own resolution should be checked against every item it unblocks before
  either is pulled — `1Lhz_38Wt`'s own spec already named this precedent
  explicitly (the `keP3_sWNy`/`vBk9_UxhS` split), so the follow-on item
  inheriting a stale scope was foreseeable at refine time, not just build
  time.

  **The first builder (subagent `ae2af8b2`, 47 tool calls, ~399s, 103k
  tokens) reported back and stopped short rather than push**, which is the
  correct outcome, but it surfaced a SECOND gap the orchestrator's own
  re-scope (above) missed: `bin/cosmic --make ci` failed at the `lint` stage
  because `docs/design/casts.md`'s fenced citation of `_make/init.tl:143`
  goes stale the instant that line's cast is replaced — a direct,
  unavoidable consequence of the Change the orchestrator itself wrote, not
  something the builder could have avoided by building differently. The
  builder correctly identified that fixing it head-on would mean editing
  `docs/design/casts.md`, which the orchestrator's own Non-goals wall
  (reserving the file for `zs1K_cWnY`) appeared to forbid, and stopped with
  its diff committed but unpushed rather than guess past the contradiction —
  exactly per its brief's "if you get stuck" instructions.
  contributed: the orchestrator wrote a Non-goals wall broad enough
  ("`docs/design/casts.md`'s prose for the class... untouched here") to
  also (unintentionally) cover the file's fenced CODE citation, which is
  mechanically tied to the very line the Change requires editing — a
  citation-accuracy consequence of an in-scope edit is a different thing
  from a prose rewrite, but the wall's wording didn't distinguish them, and
  the orchestrator's own pre-spawn review (which re-verified line counts and
  site lists) did not run the actual gate against the proposed diff, so it
  never saw the lint failure the builder found in ~2 minutes.
  improvement: (1) filed as a candidate below — a refiner drafting a spec
  that edits a line `docs/design/*.md` quotes verbatim should grep
  `docs/design/*.md` for that exact `path:line` citation string before
  finalizing, not rely on a Non-goals wall description alone to know what a
  neighboring file's edit will touch; (2) the orchestrator itself should
  have run (or asked the first builder to run) `bin/cosmic --make ci`
  against the proposed diff during refinement, before spawning, matching
  `help bar`'s "measured, not inferred" standard for a Change that touches
  a lint-checked file — this would have caught the gap for ~1 gate run
  instead of costing a full wasted builder attempt (47 tool calls) that
  correctly stopped short.

  Respec'd a third time (`spec` v3, `--force` over the still-live
  `build-q0zL_uDdq-eceb7aa0` claim since it is the orchestrator's own claim
  under a minted label) to add one narrowly-scoped exception to the
  Non-goals wall: repointing ONLY the fenced citation's header+line to
  `cosmic/searcher_test.tl:58` (the class's sole remaining live site after
  this item lands), leaving the wall's protected explanatory prose
  untouched. Re-spawned a second builder (`ad5f8fa0`) to add that one commit
  on top of the first builder's intact, unpushed `3b73ab5`, then push and
  open the PR. Full section for both builders' own `## Friction` pending —
  the second has not reported yet.

## refine EAi9_RFmX (background) — completed, spec was near-excellent but had one type-check gap
- spawned to write a `## Change` for the metatable-access-helper item (spec
  had only a `## Goal`, failed the bar outright). Subagent `a9688211`: 78 tool
  calls, 976s, 180.5k tokens. Result was unusually thorough and largely
  correct on independent orchestrator spot-check (all 5 cited files' line
  counts and cited source lines verified byte-for-byte against
  `origin/main` before spawning a builder) — but one of its two "zero
  residual cast" claims (`_types/tlast.tl`'s `local mt: any =
  getmetatable(t)`) does not type-check, discovered only when a builder
  actually tried it.
  contributed: the refiner's own `## Friction` flagged the root cause
  itself: "no built `cosmic` binary was available in this environment (no
  `o/` tree), so I could not run `--check types` to confirm the exact
  rewritten lines compile," and mitigated by citing only in-tree
  precedent (`cosmic/json.tl`'s `array_marker: any`) rather than
  verifying the new snippet directly — but the precedent's applicability
  silently depended on the precedent's `getmetatable` argument being
  itself `any`-typed, which `tag_of`'s `t: {any: any}` argument is not;
  tl's `narrowed_declaration` re-narrows a combined `local x: T = init`
  form back to the initializer's concrete inferred type
  (`metatable<{any: any}>`), and only a split declare/assign avoids it.
  improvement: same fix-shape as the sibling `q0zL_uDdq` finding above —
  a refiner without a built binary should flag every UNVERIFIED type-check
  claim as such in the spec (not present as fact), so a builder or
  orchestrator knows exactly which lines still need confirming before
  spawning full implementation; conversely an orchestrator with a
  buildable checkout (this one had one, via `git fetch` + `bin/cosmic
  --make fetch`) should spot-check a refined spec's NEW code snippets
  against `--check types` before spawning a builder, the same way it
  already spot-checked line numbers and citations — this would have
  caught the gap in ~1 command instead of costing a full builder attempt
  (55 tool calls, 493s, 113.7k tokens) that correctly stopped short and
  itself found the exact fix (verified independently by the orchestrator
  in the builder's own worktree before respec'ing a third time).
  Respec'd (`spec` v2, `--force` over the orchestrator's own
  `build-EAi9_RFmX-eceb7aa0` claim) with the two-statement declare/assign
  fix, verified by the orchestrator directly
  (`o/bin/cosmic --check types` → `Type check passed`) before respec'ing.
  Re-spawned a follow-up builder (`ac692a82`, 51 tool calls, 519s, 116.6k
  tokens) to apply just that one fix on top of the first builder's intact
  `9455817`, then push and open the PR (#1729). It also had to hand-fix
  two more `docs/design/casts.md` citations and one `cosmic/check.tl`
  coverage-ratchet row that shifted as a side effect of the new helper
  insertions — flagged in its own friction as not anticipated by either
  spec version. Reviewed by `a0089c5` (57 tool calls, 420s, 111.5k
  tokens): accept, independently re-verified every file-length
  arithmetic, both citation shifts, and the coverage row against its own
  fresh build; two mutation tests both caught the guard they targeted.
  Auto-merge enabled, later confirmed enqueued and merged (see PR-merge
  note above — same merge-queue behavior, no longer surprising).
  `done` recorded.

  **Confirmed 2nd time: the review/build brief's literal `cd /home`
  instruction for running `bin/gitboard` is wrong in this environment.**
  Both this pass's reviewers (`aaf38f06` on PR #1727 review, and this one
  on PR #1729) independently hit the same friction: `bin/gitboard` lives
  in the PRODUCT checkout (`/home/user/cosmic/bin/gitboard` here, or
  wherever that checkout actually is), not literally at `/home`, and
  `cd /home && bin/gitboard ...` fails with "no such file." Both
  recovered in one extra tool call each (a `find`/`ls`), so low
  individual cost, but it is now 2/2 reviewers hitting the identical
  wrong turn from the identical brief line. Checked the board for
  precedent before filing (`cosmic-lua/work`'s `TE1u_Un2i`/PR #34 and
  `U7bX_uuKQ`/PR #37 already fixed a related but distinct bug — a stale
  `o/bin/gitboard` path — and both are merged); this session's version
  post-dates both fixes (it already reads `bin/gitboard`, not
  `o/bin/gitboard`) but the `<PRODUCT_ROOT>` template placeholder itself
  resolved to the literal string `/home` rather than the actual checkout
  path, so it's a live, distinct bug in the substitution, not a
  duplicate. Filed as `3IuKZB9z` (captured finding, not a ready spec —
  this session could not locate the template's source to write an exact
  `## Change`), attached under the same parent (`3HyRdT1J`) as its two
  precedents for whoever refines it next.

## candidates
- **ROOT CAUSE FOUND (was misdiagnosed at first): the delay between
  `enable_pr_auto_merge` and an actual merge on an already-green PR is
  `cosmic-lua/cosmic`'s branch-protection MERGE QUEUE, not a slow
  auto-merge mechanism.** Observed on both accepted PRs this pass
  (#1727, #1728): all checks green before `enable_pr_auto_merge`, no
  merge for the next 20-35s of `pull_request_read` polling. Originally
  logged here as "auto-merge doesn't retroactively fire for an
  already-green PR" — that framing was wrong. A `pull_request.enqueued`
  webhook event ("The PR was added to the merge queue... GitHub will
  merge it automatically when it reaches the front of the queue and its
  checks pass") arrived for #1728 partway through this session's own
  poll loop, which is the actual mechanism: enabling auto-merge enqueues
  the PR, and the queue's own processing time is the delay, not a defect
  in `enable_pr_auto_merge` or in the doctrine. No countermeasure needed
  beyond correcting this session's own model — expect an enqueue delay
  (tens of seconds, observed) after every accept on this repo, and treat
  a `pull_request.enqueued` event as confirmation to keep waiting, not a
  problem. Kept here only as a corrected note for the next orchestrator
  pass reading this log, not filed as an item: there is nothing to fix.
- (pending) `help bar`/`help build` guidance: a spec whose `## Change` edits
  a line quoted verbatim by a `docs/design/*.md` fenced citation should say
  so explicitly, found by grepping `docs/design/*.md` for the exact
  `path:line` string of every changed line before finalizing — this pass
  lost a full builder attempt (47 tool calls, ~399s) to exactly this gap on
  `q0zL_uDdq`. Staying here for triage rather than filed as its own item:
  the fix is process/doctrine text in the tool itself, which this session
  did not locate the source of (outside `cosmic-lua/cosmic`/`cosmic-lua/work`'s
  item data, if not inside `cosmic-lua/work`'s own tool source — unconfirmed).
