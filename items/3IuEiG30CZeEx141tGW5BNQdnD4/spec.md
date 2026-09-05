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

## refine EAi9_RFmX (background, in flight)
- spawned to write a `## Change` for the metatable-access-helper item (spec
  had only a `## Goal`, failed the bar outright). Full section pending — the
  refine agent has not reported yet.

## candidates
- (pending) doc note in `help review`/orchestrate about already-green PRs and
  auto-merge not retroactively firing — staying here for triage, not filed as
  its own item: only observed once, not yet confirmed as a repeat pattern.
- (pending) `help bar`/`help build` guidance: a spec whose `## Change` edits
  a line quoted verbatim by a `docs/design/*.md` fenced citation should say
  so explicitly, found by grepping `docs/design/*.md` for the exact
  `path:line` string of every changed line before finalizing — this pass
  lost a full builder attempt (47 tool calls, ~399s) to exactly this gap on
  `q0zL_uDdq`. Staying here for triage rather than filed as its own item:
  the fix is process/doctrine text in the tool itself, which this session
  did not locate the source of (outside `cosmic-lua/cosmic`/`cosmic-lua/work`'s
  item data, if not inside `cosmic-lua/work`'s own tool source — unconfirmed).
