# friction — 2026-09-07 work pass 5 (sonnet agents, cap 2)

plan: tidy (X3Fv → not-planned dup of rG1E; Infz → superseded by B6bC; c70t children re-ranked Qa2H, 9doI, Jwsz, 7Vds, ZD1x; kkDm amended with the make-flag face), then Qa2H + Jwsz, 9doI + kkDm, 7Vds + jVEN ($X as $T), then B6bC. every spawn preceded by a module read of the spec's Evidence.

## tidy (01:55 UTC)
- X3Fv_c3NJ → not-planned (dup of rG1E_0jFl); Infz_bnpL → not-planned (superseded by B6bC_kqMZ); c70t children re-ranked; kkDm amended (make-flag face + the cold reproduction recipe). 1 call each; `spec --base` from the ref sidecar worked first try.
- `new --parent` filed the first child of «toDR_PvTt» unranked and the `--after` chain for the next four failed on it — «7Vds_BXrP» in action, 2 wasted calls; ranked by hand.

## builders spawned (01:58): Qa2H_5whT (work: COMMENT review on own PR), Jwsz_pT5P (cosmic: board from a linked worktree)
env blocks measured: ghwrite.tl:94-118, gitverdict.tl:280-299, Pull lacks author (grep login → 0), api.tl has no GET /user; bin/gitboard:100-118, gitboard_root_test.tl 6 cases.

## builder Jwsz_pT5P (bin/gitboard from a linked worktree) — cosmic
numbers: tool_calls=53 wall=573s tokens≈129k; errors: see above. agent's account (2): (1) `--make test` nests TEST_TMPDIR inside the real worktree, so a git-walking probe found the REAL repo from a "no git" fixture — ~10 calls; the builder added a `--show-toplevel == ROOT` guard (right, minimal). countermeasure: the env block for anything that walks up with git names this nesting; added to 9doI's spawn prompt. (2) global git config carries a personal identity — one amend. countermeasure: every builder prompt now says `git -c user.name=Claude -c user.email=…` explicitly (was only in the env block).

## Qa2H_5whT builder (work: COMMENT review on own PR) — agent a25971ee27ba4d57b
numbers: 87 tool calls, 184k tokens, 13.2 min; first edit at call 34; 0 errors; gh.tl read 8x.
result: branch 3IyIFkBa pushed, gate green (76 checks, 655 tests); opened as work#71.
- goal: fit the latest_request_changes extension under gh.tl's 500-line cap (483 → 17
  lines of slack). happened: first draft landed at 508, two trim rounds (~5 calls).
  countermeasure: the brief's step 1 should ask for the planned delta against slack,
  not the bare wc -l.
- goal: keep own_login's per-process cache from making fake-transport tests order-
  dependent. happened: ~10 min inferring the per-file test process model from
  _tool/testrun.tl; resolved by exposing `api.own_login` as a swappable field.
  countermeasure: env block names "must be stubbable" whenever a spec says "cached".
- goal: Teal declare-then-assign in a closure. happened: 4 identical compile errors,
  one sed pass, 2 calls. no countermeasure (language rule).
- orchestrator: reported out-of-scope finding — brief.tl round_context counts only
  CHANGES_REQUESTED, so own-PR bounces under-count ROUND_NUMBER → file as item.

## PR 1782 (Jwsz) CI red — orchestrator
numbers: 4 calls to diagnose + fix. failure: fixture `git commit` with no identity in
CI's builder user (Author identity unknown). fix by hand: explicit `-c user.name/-c
user.email` on the command, as vcs_test/refstamp_test already do. countermeasure:
the builder brief's TEST_TMPDIR note should also say "any git commit in a fixture
carries -c user.name/-c user.email; CI has no global identity".

## 9doI_nexi builder (work: worktree refuses an unclaimed item) — agent afb0df044ca1762f7
numbers: 75 tool calls, 158k tokens, 10.4 min; 0 errors; gate green (653 tests); mutation done.
- goal: one refusal message shape for "claimed by another session". happened: the spec quoted
  one literal line and the env block said "name whose it is" — ~10 min of re-reading to
  decide these are two templates. countermeasure: a spec that quotes one refusal line
  quotes every refusal line.
- goal: two-file Change scope. happened: a new verb parameter drags `_work/gitcommands.tl`
  (flag) and `_work/gitboard.tl` (dispatch) along; one extra grep round. countermeasure:
  the work-repo env block states "a new verb flag touches gitcommands.tl + gitboard.tl"
  as a standing fact, and the brief's scope clause allows mechanically required call sites.
- measured facts all matched the live tree; no rework.

## PR 1782 (Jwsz) reviewer — agent a9d97bf4280e04782
numbers: 17 tool calls, 85k tokens, 4.1 min; accept, mutation caught (3/7 fail). full shape.
friction: none reported; every measured env fact held. hand-written env block +
head-moved note is the shape to keep.

## kkDm_pEOC builder (cosmic: coldbuild_test include-dir order + fixture) — agent abd9afbd9a81b9210
numbers: 68 tool calls, 146k tokens, 14.2 min; gate green (5 stages, with --min 76).
- goal: a fixture that exercises include-dir order. happened: first version added the
  fixture dir as an EXTRA include-dir instead of REPLACING `.`, so the test passed for
  the wrong reason; the mandated mutation step caught it (~15 calls of rework).
  countermeasure: when a brief's probe recipe substitutes a directory for `.`, the env
  block says "as the tree root, not an additional include-dir" in those words.
- goal: fill `<caller>`/`<callee>` in the spec's quoted message. happened: ~10 min to
  learn the tl checker names neither, only `given N, expects M` + file:line:col.
  countermeasure: a spec that quotes a message derived from tool output quotes the
  tool's real output first.

## work#71 (Qa2H) reviewer round 1 — agent aca040202fb779f7d
numbers: 25 tool calls, 97k tokens, 3.7 min; request-changes (mutation NOT caught: no test
pinned the first-line marker); the bounce itself 422'd — the pinned gitboard is the
pre-fix code and #71 is the token's own PR, the exact bug under review.
- goal: `gitboard show ID --session X`. happened: `show` takes no --session; 1 call lost.
  countermeasure: the brief's mechanical block puts --session only on take/verdict.
- orchestrator: fixed by hand (2 tests in _work/gh_test.tl, 8c4124d); first mutation
  attempt did not compile (unused `first` → warning → error), so a mutation on this
  code must keep every local used — noted for the env block's mutation text.
- structural: a fix to verdict posting cannot be bounced through the tool that carries
  the bug; only accept works until the pin moves. accepted cost, no item.

## work#72 (9doI) reviewer — agent a49512c9b9c2b3d74
numbers: 25 tool calls, 98k tokens, 2.4 min; accept, mutation caught (1/11 fail). full shape.
- goal: `gitboard show ID --session`. happened: rejected, 1 call lost (second reviewer
  this pass). countermeasure: same as work#71's — the brief's mechanical block, or
  `show` accepts and ignores --session. → fold into the friction item.

## work#71 (Qa2H) reviewer round 2 — same agent, resumed
numbers: 7 tool calls, 106k tokens (context carried), 1.0 min; accept, mutation caught.
- goal: record the verdict from the orchestrator's message. happened: my message and
  the env blocks wrote `verdict accept ID`; the real order is `verdict ID KIND`; 1 call
  lost. countermeasure: env blocks quote the verb's usage line, not a remembered shape
  — fixed in env_1783 by message; template corrected for the rest of the pass.

## PR 1783 (kkDm) reviewer — agent ab1f050e394c8df7e
numbers: 15 tool calls, 90k tokens, 2.9 min; accept, control-case mutation behaved.
- goal: verdict syntax. happened: brief shipped `verdict accept ID` (my env block, not the
  tool's brief, which is right); corrected mid-task by message, 0 calls lost.
- goal: remove the review worktree. happened: cwd was inside it → `pwd` noise, 1 extra
  call. countermeasure: env block says "cd /home/user/cosmic before worktree remove".

## VQJe_6hgY gitboard pin bump → 2026-09-07-81e0660 — orchestrator hand-build
numbers: 4 calls (file, rank, spec-amend+take+bump+push+open). PR 1784.
- `rank --after` refused across parents (kkDm is under a different container) — fine,
  but `new --parent` still left the child unranked (7Vds, being pulled now).
- spec bar: a pin bump that downloads a release asset must declare the work repo under
  Access, read-only. countermeasure: the pin-bump spec template carries that line.
- `worktree` ran to completion on the UNCLAIMED item after `take` was refused — the #72
  bug itself, on the pin this bump replaces. no item: fixed by the bump.

## PR 1784 (VQJe pin bump) reviewer — agent a555682945a0d23ee
numbers: 5 tool calls, 68k tokens, 1.1 min; accept. script shape, no worktree.
- goal: check 4 as written (`diff origin/main..HEAD --stat`). happened: main had moved
  (#1783 landed), 3 files shown, 2 extra calls. countermeasure: env blocks diff against
  the merge-base sha, never the live main.
- goal: the condensed verdict line. happened: `--head "" is not a git sha` — verdict
  needs `--pr N --head SHA`; 1 extra call. countermeasure: env block copies the tool
  brief's full verdict line verbatim (the sed-filled one) instead of condensing it.

## 7Vds_BXrP builder (work: new --parent ranks last) — agent adfebd5099002a6e7
numbers: 83 tool calls, 184k tokens, 16.5 min; gate green (660 tests); mutation done.
- goal: the env block's four-file footprint. happened: `--make test _work` found 6 tests
  in 3 other files whose fixtures relied on the old unranked default; ~20 calls.
  countermeasure: an env block's file list is a prediction — say "run --make test on
  the package before trusting it", and a behaviour-changing spec's Change names the
  fixtures that depend on the old behaviour (grep for the old verdict text first).
- goal: a done-item refusal test failing on a stale index after a no-op write. happened:
  ~15 min hand-tracing store.close; the idiom already exists in gittake_test.tl.
  countermeasure: item — doc comment on commit_and_publish naming the raw-write +
  store.close idiom (or a lint for storewrite.save without a following close).
- `--make run /tmp/x.tl` refuses a script outside the root; AGENTS.md's one-off guidance
  does not say so. countermeasure: one sentence in AGENTS.md's `-e`/`/dev/stdin` para.

## jVEN_hgxX builder (cosmic: $X as $T cast patterns) — agent a3b8458677618cf6e
numbers: 108 tool calls, 251k tokens, 26.2 min; gate green (5 stages); mutation done.
- goal: probe an edited module with a throwaway script. happened: o/bin/cosmic serves the
  LAST BUILD's embedded copy of cosmic.*; ~4 calls re-probing a stale module.
  countermeasure: AGENTS.md's "--check types … last build" paragraph extends to any
  script run against an edited cosmic/* module — build first (or `--make run`).
- goal: parse `$X as $T` as a pattern. happened: a bare cast is not a Teal statement;
  neither spec nor env block said so; ~6 calls probing tl's grammar. countermeasure:
  a spec whose Evidence is a syntax error names WHERE it fails (parse vs match) —
  the refiner reproduces the error and reads the message before writing Change.
- goal: fit in match.tl. happened: ignored the brief's own "estimate first", wrote
  inline to 497 lines, redid as match_cast.tl; ~8 calls thrown away. countermeasure:
  the brief's slack line becomes a hard step: "if delta > slack, the new module is
  the plan, not the fallback".
- `--fix` did not settle a multi-line record field's continuation indent; 2 calls.
  countermeasure: item — formatter fixes continuation indent of record field types.
- orchestrator: out-of-scope finding — sys/help.md never documents `$NAME:PATTERN`
  (from #1777) → item.

## orchestrator — pull queue stalls behind unclaimable reviews
three times this pass (7Vds behind cosmic#1784, ZD1x behind work#73 then cosmic#1785) a
free slot and a ready brief waited 5–25 min on a PR's CI because `take` counts an
unclaimable review as "a verdict you can give". filed «yVfw_jhhk». `show`'s false
`absent:` for work-repo paths from a cosmic checkout filed «66ad_YWIV».

## orchestrator — new pin mechanics
under 2026-09-07-81e0660 `gitboard worktree ID` needs `--session build-<handle>-<sid>` (the
claim's label), or it is refused naming the default identity; 1 call lost on ZD1x.
countermeasure: `gitboard help orchestrate`'s pull step shows `take` and `worktree` with
the same `--session` flag.

## work#73 (7Vds) reviewer round 1 — agent aed7e37fedf60e40e
numbers: 39 tool calls, 109k tokens, 4.3 min; request-changes (real: verdict-line total
counted stale order entries show skips); bounce 422'd AGAIN on the new pin.
- goal: judge #1 (same count as show). happened: ~10 calls + a probe script to find the
  stale-order interaction from place's docstring — nothing in spec/brief named it.
  countermeasure: a spec that adds a second rendering of an existing computation names
  the existing computation's function and says "call it, do not re-derive".
- 422 despite work#71: the token is an app installation token, `GET /user` fails, the
  safe fallback keeps REQUEST_CHANGES. filed «4xPu_RtV2» (retry as marked COMMENT on 422).
- orchestrator fixed by hand: position_in(parent, id, index) skips entries whose item's
  parent moved; test added; 6/6; pushed.

## PR 1785 (jVEN) reviewer — agent ab8959810469277c9
numbers: 29 tool calls, 108k tokens, 4.0 min; accept, mutation caught (2/17 fail).
friction: none; `--find` refuses a probe outside the project root (documented by its
own message).

## work#73 (7Vds) reviewer round 2 — same agent, resumed
numbers: 8 tool calls, 115k tokens (context carried), 1.2 min; accept, mutation caught.
friction: none.

## ZD1x_zeG6 builder (work: show prints the ci line) — agent a012826c5f8dfc207
numbers: 66 tool calls, 149k tokens, 10.9 min; gate green (664 tests); first pass, no rework.
- goal: the print condition. happened: the env block said "a todo item, or a doing item
  with pr == 0" — `pr <> 0` alone makes the state view read doing, so the two collapse;
  3 calls reading flow.tl/indexddl.tl. countermeasure: an env block that names a state
  names the SQL view that defines it.
- the spec-drift note (done/total not in the cache) and the fixture pointer saved the
  exploration — keep measuring those.

## work#74 (ZD1x) reviewer — agent a8c5693bc75f88b52
numbers: 22 tool calls, 92k tokens, 3.5 min; accept, mutation caught (1/20), spec drift
verified honest against the DDL.
- goal: judge 4 as worded (`gitboard.main("show", …)`). happened: the file's convention
  is `show_and_capture` → `cmd_show`; 1 extra grep. countermeasure: env blocks name
  the test file's own helper when one exists (grep the test file for the entry point
  before writing the judge).

## 4xPu_RtV2 builder (work: verdict 422 → marked COMMENT) — agent acb222a549dd0d180
numbers: 53 tool calls, 128k tokens, 8.3 min; gate green (664 tests); mutation done.
- goal: read a `ci: FAIL (fmt)`. happened: the informational "HEAD is not a descendant of
  origin/main" line printed right above the verdict read as the cause; ~2 calls
  tracing ancestry before finding the fmt diff in o/fmt-summary.txt. countermeasure:
  item — the gate prints the ancestry note BEFORE the stage output, not beside the
  verdict, or the verdict line names the failing file for fmt.
- returned "comment-fallback" in slot 2 on success: reviewer judges against D20's
  fallible-effect shape (slot 2 is the error).

## work#75 (4xPu) reviewer — agent af9f02a568d92bcf1
numbers: 23 tool calls, 109k tokens, 3.7 min; accept, mutation caught. slot-2 success
value judged in charter (mirrors merge_pull in the same file).
- goal: run the work repo's tests. happened: reached for /home/user/cosmic/o/bin/cosmic
  against a work worktree; a checker mismatch on store.tl cost ~2 calls + a stash round
  trip (a bare `git stash` in a shared-stash environment — a rule breach, no damage
  seen). countermeasure: work-repo env blocks say "the worktree's own bin/cosmic, never
  cosmic's o/bin/cosmic"; the reviewer prompt bans bare `git stash`.

## orchestrator — yVfw's spec was wrong on first filing
filed «yVfw_jhhk» from the refusal text alone; reading gitgate.tl at pull time showed the
rule already clears running/red heads, and the gap is only that `take --open`/`--pr`
write no ci_checks row (nil never excludes). re-specced before spawning (+4/-4). cost: 3
calls + one --force spec. countermeasure: a countermeasure item names the function it
changes — the refiner greps the refusal text to its source before writing Change.

## B6bC_kqMZ builder (cosmic: casts allowlist) — agent aca9e562a5c216e33
numbers: 145 tool calls, 342k tokens, 39.1 min; gate green (5 stages); mutation done.
- goal: trust the env block's "17 classes". happened: my uniq -c counted the tsv header
  as a class; 2 calls re-deriving. countermeasure: measure with `tail -n +2`; an env
  block's number that contradicts the spec's is re-derived before it is written down.
- goal: tsv rows as the oracle. happened: the AST walk counts `as` TOKENS, the old lexer
  counted LINES — 3 rows hid 4 casts; ~40 min, 6 calls, one throwaway script.
  countermeasure: gone with the tsv; the PR body records the true count (146).
- goal: patterns alone. happened: 12 of 16 kinds needed an explicit residual (identical
  rendered type in the same file); the env block guessed 4. inherent to the domain —
  the spec's "pattern plus scope" was optimistic; noted for 0LDT (nil-flow) whose 7
  positions are SYNTACTIC and should separate cleanly.
- goal: run a scratch script under o/. happened: `--make run` refuses o/ paths; plain
  `bin/cosmic script.tl` works; 2 failed calls. countermeasure: AGENTS.md's one-off
  paragraph says "a throwaway analysis script: `bin/cosmic script.tl` from the root".

## PR 1786 (9RCW pin bump) reviewer — agent ab0efc08ee08b7623
numbers: 3 tool calls, 66k tokens, 0.7 min; accept. friction: none (env block fixed after
1784's two findings: merge-base diff, full verdict line).

## orchestrator — `sync` before a pull clears the unobserved-CI stall
running `gitboard sync` right after opening a PR records its CI as running, and the
existing ci_clears_debt rule then lets a pull through — the stall yVfw addresses was
avoidable all along with one verb. countermeasure (until yVfw lands): the orchestrate
page's pull step reads "sync, then take"; after yVfw, `take --open` seeds the row itself.

## yVfw_jhhk builder (work: take seeds a running CI row) — agent aa1533d5e8cc2af82
numbers: 81 tool calls, 158k tokens, 11.9 min; gate green (668 tests); mutation done.
- goal: two implementation files + one test. happened: three other test files read the
  same cache row (show's ci line, next's live freshness window, review_debt's fixture);
  ~10 calls, ~15 min. countermeasure: an env block that adds a cache WRITE greps for
  every READER of that table (`grep -rn ci_checks\|current_state _work`) and names them.
- `_work/ciobs.tl`'s doc comments answered the freshness-window question; no gap.

## uwLi_Bno2 builder (work: bounce predicate shared by gh.tl and brief.tl) — agent a7c8d42d2016029eb
numbers: 71 tool calls, 126k tokens, 9.1 min; gate green (677 tests); mutation done.
- goal: the spec's expected ROUND_NUMBER. happened: Change said 3, Evidence implied 2;
  a probe test (4 calls, ~10 min) settled it at 2. countermeasure: a spec's concrete
  expected number is taken from running the current code, not from prose arithmetic —
  I wrote that spec; the refiner (me) runs the formula before quoting a value.
- new `_work/*.tl` module → coverage ratchet "not in baseline" → hand-edit
  .cosmic-coverage (the work repo's cosmic pin predates #1778); one extra coverage run.
  countermeasure: bump the work repo's cosmic pin to ≥ 2026-09-07-2b2002d (item).

## PR 1787 (B6bC) reviewer — agent ab1bf455be1d27a72
numbers: 43 tool calls, 154k tokens, 10.5 min; accept, oracle check zero disagreements,
mutation caught (both guards held). full shape with a scratch-script oracle probe.
- goal: insert an unjustified cast "at the top of a function" in cosmic/fs/init.tl.
  happened: that file is a pure interface record, no function body; 1 extra call to
  find another insertion point. countermeasure: acceptance recipes name a file that
  actually has a function, or say "anywhere in the tree" instead of a specific file.
- goal: clean up a scratch oracle script. happened: leftover scratch.tl/scratch2.tl
  broke the next --make test (whole-tree type-check sees every .tl file); one failed
  run (~15s). countermeasure: review briefs say "delete a scratch script before the
  NEXT test run, not just before recording the verdict".
- three non-blocking findings reported: two avoidable explicit residuals (generic T,
  binding constant by name), near_matches ignoring `where` scope, one stale carried-
  patch comment (3p/tl/tl_patch/cast.tl:73) referencing a file this PR deletes.

## work#77 (uwLi) reviewer — agent ab9a03d4fe18bfaad
numbers: 18 tool calls, 85k tokens, 2.9 min; accept, mutation caught (2 files).
- goal: judge 2's "3 vs 2" number. happened: a few extra calls reading brieftext_review's
  ROUND template to confirm the spec's own worked example was arithmetically wrong, not
  the PR. countermeasure: an env block that inherits a spec's stated number flags it as
  possibly wrong rather than presenting it as fact to verify against.

## work#76 (yVfw) reviewer — agent a87fdeabe5872b59f
numbers: 40 tool calls, 122k tokens, 6.7 min; accept, real finding (take_open's --open
seed is untested — no child.run/ls-remote mocking seam exists in the suite).
- goal: run the named mutation against the named test. happened: the brief's mutation
  site (take_open) and its named catching test (:345, which actually exercises the
  --pr N seed in gitverbs.tl) are not connected; ~6 calls to trace cmd_take's open/pr
  branching and re-target the mutation. countermeasure: env blocks name which SITE a
  mutation's catching test actually exercises, not just a line number to edit.
- reported: gitboard's own merge attempt 403'd on GraphQL (same as before); landing via
  the GitHub tool is still the path, unchanged.

## orchestrator — session label extraction bug in the pin-bump hand-build
`echo $PID | tail -c 9` on a 27-char KSUID id gives the last 8 chars with no separator
(`7rXQ3Lm0`), not the underscored handle (`7rXQ_3Lm0`) gitboard actually renders and
records as the claim label — take --open then refused, needing a second call with the
label copied from the refusal text. countermeasure: derive the session label from the
board's OWN rendering (the `new` verdict line's bracketed handle, or `gitboard show`),
never by string-slicing the raw id.

## PR 1788 (7rXQ pin bump) reviewer — agent a88d535ac0bf6f661
numbers: 3 tool calls, 67k tokens, 0.9 min; accept. friction: none.

## pass summary
13 PRs landed: cosmic #1782–1788, work #71–77. Items closed: Jwsz, Qa2H, 9doI, kkDm,
jVEN, 7Vds, ZD1x, 4xPu, B6bC, uwLi, yVfw, plus three gitboard pin bumps (81e0660,
ee58808, 63bcb7a) and one cosmic pin/ci-floor tail from the prior pass. Follow-up items
filed: uwLi's round_context gap, 4xPu's 422 fallback, work#76/#77's own findings
(round-context arithmetic verified not a defect), B6bC's three findings (two avoidable
explicit residuals, near_matches scope, one stale carried-patch comment), and yVfw's
own child.run mocking-seam gap. Recurring countermeasure themes: env blocks should
name the SQL view or test-file entry point behind a stated rule, not just its refusal
text; a mutation's "catching test" should be verified against the actual call site it
exercises, not assumed from a line number; new gitboard mechanics (a bumped pin's
--session requirement on `worktree`, the `sync`-before-pull workaround) surprised the
orchestrator at least once each before being logged.
