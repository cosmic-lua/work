# friction: 2026-09-05 work9 (/work 9 --routine)

## orchestrator
- goal: claim «J9eH_ond1» ("cosmic.sqlite: three small additions") and emit its
  builder brief. actually happened: `gitboard brief builder J9eH_ond1` produced a
  brief for repo `cosmic-lua/work` ("Open a PR from `3ItBZfrA` to `main` in
  `cosmic-lua/work`"), but the item's own `## Change` names only `cosmic-lua/cosmic`
  paths (`cosmic/sqlite/extras.tl`, `cosmic --docs`) — porting patterns FROM
  `_work/cachedb.tl`/`_work/find.tl` (prior art) INTO `cosmic.sqlite`. `show
  J9eH_ond1` printed no explicit `repo:` line, so the brief tool fell back to the
  item's parent goal's repo («i2De_o66q» "G8 — the flow system", the board's own
  epic) instead of the repo the spec's files actually live in. One `gitboard show`
  plus a `grep` for `repo:` on the parent to confirm the inheritance, ~3 tool calls,
  caught before any worktree/agent was wasted. contributed: an item filed under a
  goal whose own repo default is `cosmic-lua/work` but whose spec content targets
  a different repo, with no explicit `--repo` override recorded at file time.
  improvement: `gitboard new`/`spec` could warn (never refuse) when a spec's
  `## Change` file paths don't match the parent goal's default repo's own tree
  shape (e.g. no `cosmic/` directory in `cosmic-lua/work`) — a gate over the tool,
  ranked above a doc note. Fixed in place with `gitboard set J9eH_ond1 --repo
  cosmic-lua/cosmic` and the brief re-emitted; not filed as a candidate below
  because it needs the tool's own repo-shape awareness, which is a research
  question, not a bar-passing spec yet.

- goal: emit briefs for two research-shaped items («10WB_be6U», «CCB2_BBra» — both
  say "Change: Research... deliverable is a `--result` handover" in their own spec).
  actually happened: ran `gitboard brief builder ID` for both (matching the
  generic pattern used for the other 5 build items), producing the generic builder
  template whose "What to do"/"Final report" sections talk about pushing a branch
  and opening a PR — wrong shape for a no-diff research handover. Caught for
  «10WB_be6U» only after composing the Agent prompt by hand-rewriting those
  sections from memory of the doctrine (`gitboard help orchestrate`'s "brief
  research ID" line), already spawned before the mismatch was checked against the
  tool's own research template. Caught for «CCB2_BBra» before spawning: diffed the
  builder brief against a fresh `gitboard brief research CCB2_BBra` and found the
  correct one names a read-only clone, forbids any commit/push/PR, and asks for a
  literal spec-update + capture-item drafts instead — required a `drop --force` +
  re-`take` under the `research-` (not `build-`) session label to match, ~4 extra
  tool calls. contributed: `gitboard help orchestrate` names `brief research ID`
  as its own kind but nothing at pull/claim time flags "this item's spec says
  Change is Research" the way the `bar` check flags a missing `## Change` — the
  orchestrator has to notice the word "Research" in the Evidence/Change prose
  itself. improvement: `next`/`take`'s output could carry the item's spec-declared
  kind (research vs. build) alongside the title, the way it already carries
  overlaps — a small addition to the existing print, ranked above a doc note; a
  candidate, not filed as its own item this pass (needs a look at where `next`
  derives its line before a spec can be written). «10WB_be6U» was left running
  under its hand-adapted prompt rather than killed and restarted, since its
  instructions are substantively equivalent to the tool's research template
  (no-diff, `--result` handover, no `gitboard` calls) — only re-derived by hand
  instead of read off the tool.

## build utpf_HTkH (claude) — no diff, item closed not-planned, ~168s, 12 tool calls, 64.6k tokens
- goal: bump the cosmos pin past FTS5 and fix `_cli/main_handlers.tl`'s four
  `unix.mkstemp` callers. actually happened: the fresh worktree off `origin/main`
  already carried both — PR #1705 (an unrelated, broader pin-bump item) landed the
  identical fix as collateral before this item's branch was cut; `git diff` was
  empty, `--make ci` was already `ci: PASS`. contributed: the item's Evidence was
  gathered against an older `main`; nothing in the spec or brief was wrong, this is
  the "re-run the spec's measured commands" step catching a fully-resolved case
  rather than a moved number. improvement: none ranked above the existing
  instruction (already followed correctly) — a genuine race between board latency
  and a fast-moving `main`, not a gap in the tool or doctrine. orchestrator action:
  `gitboard done utpf_HTkH --reason not-planned --force --why "..."` citing PR
  #1705, then removed the now-unneeded worktree/branch.

## build LbjX_BhTY (claude) — stopped short, blocked+released, 501s, 65 tool calls, in=124 out=2168 cache_read=5829385 cache_create=107469
- goal: implement items 1–4 of the flags `--`-terminator item, then item 5 (a test
  that `cosmic --docs -- "--recipe"` reaches the handler intact, per the spec's own
  claim that this "already" works). actually happened: items 1–4 landed clean,
  committed at `7cc369f`, all green; item 5's premise is FALSE on this tree — `cosmic
  --docs -- "--recipe"` silently drops the query and prints the full module index
  instead. Root cause is one layer up from this item's scope: `cmd/cosmic/main.tl`'s
  `parse_args()` pre-scan treats the FIRST bare `--` as cosmic's own
  option/script-name boundary, so a `--` meant to terminate `--docs`'s own optional
  argument gets consumed there before `cosmic.flags` ever sees the value;
  `_cli/args.tl`'s `resolve_optional_arg` independently has the same bail-on-`--`
  shape. ~15 of the agent's 65 tool calls went to pinning this down (a debug script
  via `cosmic.child`, then tracing `_cli/args.tl` and the dispatcher's pre-scan) —
  the builder's own friction entry says a one-line comment at the pre-scan's `if a ==
  "--"` branch would have saved most of it. Builder correctly stopped rather than
  widening scope into the dispatcher, left the diff (items 1–4 plus the now-failing
  item-5 regression test) committed unpushed on `3ItQ4xOm`. contributed: the spec's
  Evidence asserted an unverified fact about a DIFFERENT layer (the dispatcher, not
  `cosmic.flags`) as settled; nothing wrong with the build doctrine — this is exactly
  "re-run the spec's measured commands" catching a false premise before it reached a
  PR. orchestrator action: filed «WgbGUO99» (the dispatcher bug, full repro +
  root-cause trace ported from the report), `block LbjX_BhTY WgbGUO99`, `drop
  LbjX_BhTY --force` (the agent had already reported, so its own claim was no longer
  live) — the committed-but-unpushed diff stays on the branch/worktree for the
  respec once the blocker lands. secondary: also caught a bare `cosmic file.tl`
  reading as a passed test with zero output (not enrolled without `--make test`,
  per D29) — cost ~3 calls, no tree/doc gap, a habit note in the agent's own
  friction section.

## research 10WB_be6U (claude) — no-adopt, --result handover, 790s, 81 tool calls, in=164 out=1148 cache_read=8318585 cache_create=126324, errors=3
- goal: run `--make run` against the throwaway prototype "in `o/`" per the spec's own
  wording. actually happened: `--make run` refuses any path under `o/` (excluded by
  the project model — "no such source"), a wall none of the other `_build/*.tl`
  examples the spec was modeled on would hit since they live outside `o/`. Cost
  ~10 min / 4 calls tracing `_make/runverb.tl`'s `resolve()`/`file_of()` before
  finding it, then discovering by experiment (not by doc) that a BARE
  `o/bin/cosmic o/proto/foo.tl` (no `--make`) resolves `require("_cli.*")`/
  `require("_make.*")` against the live tree, not just the binary's embedded copies —
  `CLAUDE.md` only documents this bare-vs-`--make run` distinction for `_perf`
  specifically. contributed: no doc states that an `o/`-resident script and
  `--make run` are mutually exclusive, or that bare execution's live-tree resolution
  generalizes beyond `_perf`. improvement: a one-line note in the build-system docs
  on when bare-script requires resolve against the live tree vs. the embedded
  snapshot — a doc fix, not filed as its own item this pass (folded into the
  candidate below since it's small enough to land inline next time that doc is
  touched, not on its own).
- goal: express `nil_returns`' count "as a join" per the spec's own Evidence framing.
  actually happened: after reading all 380 lines of `_cli/nilreturn.tl` (~20 min),
  found the count comes from a stateful, ordered frame-stack walk matching
  function/record/block nesting — not expressible as a SQL `WHERE`/`JOIN` — and had
  to port ~230 lines of that algorithm into the prototype to measure honestly rather
  than silently re-lexing. contributed: the spec's own Evidence stated "nil-returns a
  join" as settled, symmetric with casts' one-line `WHERE text='as'`; it isn't. This
  is exactly the kind of fact a decision record exists to surface, and the report's
  central no-adopt finding (rule (b)) rests on it — not a doctrine or tool gap, a
  correct research outcome.
- goal: get a fair generation-time number. actually happened: the first (row-by-row)
  implementation measured 3.1–3.8 s; unsure if that was an insert-pattern artifact,
  spent one more round (~15 min, 3 calls) building a 500-row-batched `INSERT...VALUES`
  variant — an intermediate scratch script hit 3 avoidable errors (a `db:transaction`
  callback missing its `boolean, string` return annotation, a `#` on a map instead of
  an array, a Write-before-Read tool-order slip) before landing at 2.7–3.3 s, same
  verdict. Not wasted (materially strengthens the no-adopt case) but the spec's
  Change section didn't anticipate needing a second implementation pass to trust the
  first measurement.
- orchestrator action: composed the item's full revised spec (Evidence/Change/
  Non-goals unchanged, `## Result` appended with the agent's numbers and the
  determinative rule-(a) failure) from the report, `gitboard spec 10WB_be6U <file>
  --force --why` (claim was the agent's, already reported), `take 10WB_be6U --force`
  then `take 10WB_be6U --result` — now `awaiting review`. Worktree/branch produced no
  diff (confirmed clean) and were removed.

## orchestrator (reconciliation)
- goal: force-take a claim held by an already-reported agent's own session label
  (`build-10WB_be6U-5c8fc82c`) to record its `--result` handover. actually happened:
  ran `gitboard take 10WB_be6U --force --why ...` with no `--session`, which defaults
  to the ORCHESTRATOR's own bare identity, not the original label — the claim moved
  from `build-10WB_be6U-5c8fc82c` to the orchestrator's literal session id. That's
  harmless in isolation, but "one claim per worker" is enforced against the literal
  calling identity: the very next reconciliation (`take CtYH_Gmrg --force --why ...`
  for its PR) was refused with "5c8fc82c... already holds 3ItPEbNr" — MY OWN prior
  reconciliation call had used up my one claim slot. Fixed by re-running with
  `--session build-CtYH_Gmrg-5c8fc82c` (the label the builder already claimed under)
  instead of `--force`, which succeeded directly with no collision. contributed:
  `gitboard help orchestrate`/`help review` never states that a reconciliation
  action (`take ID --pr N` / `take ID --result` on an agent that already reported)
  should reuse that agent's own minted `--session` label rather than fall back to
  the orchestrator's bare identity — the two "how do I act as this finished worker"
  paths (`--force` with no session vs. `--session <label>`) read as interchangeable
  but are not: the first spends the orchestrator's own one claim slot, the second
  doesn't. improvement: state explicitly, in `help orchestrate`'s "Reconcile the
  wave" paragraph, that every reconciliation call should pass `--session <the
  minted label>`, never bare `--force`, precisely to avoid this collision — a doc
  fix, ranked above a tool change since the mechanism (one-claim-per-identity) is
  working as designed. Cost: 1 extra refused call, ~1 min, no lost work. Every
  subsequent reconciliation in this pass uses `--session <label>` from here on.

## build CtYH_Gmrg (claude) — PR #1719, 1088s, 97 tool calls, in=186 out=4033 cache_read=12777106 cache_create=189669, errors=5
- goal: locate the built doc index at the spec's stated `--- reads:` path
  (`o/embed/cosmic/.docs/index.lua`). actually happened: that path doesn't exist —
  the real generated path is `o/cmd/cosmic/embed_gen/embed/.docs/index.lua` — cost
  ~10 min of `find`/`grep` before the agent found and followed the existing
  precedent (`cosmic/doc/public_test.tl` calling `docs.embedded_index()` against the
  freshly-built binary at runtime, no `--- reads:` declaration) instead. contributed:
  the spec's cited path is stale/wrong for this repo's actual unit-output-directory
  layout. improvement: fix the path in future specs referencing generated output, or
  point at the precedent test directly — a spec-writing habit, not a tool gap.
- goal: implement `return_slots(signature): integer` correctly per four terse
  unit-test examples with inconsistent shapes (a bare `"boolean, string"` vs. a
  parenthesized `"function(Entry): (WalkAction, T)"`). actually happened: ~20 min of
  manual pattern simulation to reverse-engineer one algorithm satisfying all four
  plus nested-callback signatures generally, catching (in the process) that the
  spec's OWN evidence census script undercounts correctly: it stops at the first
  `):` in the text, so `cosmic.fs.visit`'s `visitor` parameter type
  (`function(Entry, T): (WalkAction ...)`) fools it into counting 3 declared slots
  where the true count is 2 — `fs.visit` was one of the claimed nine mismatches but
  was never actually wrong. The agent verified this by diffing the naive vs. correct
  algorithm over the whole index (exactly one disagreement) and left `fs.visit`'s doc
  untouched, fixing the genuine 8. contributed: this is a spec Evidence section
  reporting a buggy measurement as settled fact, discovered only by building the
  correct version the spec itself demanded — a good outcome (research doctrine
  working as intended via the build step), not a doc/tool gap, though a worked
  algorithm sketch (matching how the buggy version got one) would have saved the
  20 min.
- minor: 5 transcript errors, none costly — a `cosmic - <<EOF` stdin-script attempt
  that isn't supported (1 call), a premature `--check types` run before a helper
  record field existed yet (expected, self-corrected next edit), 2 `Grep` calls
  issued from the wrong cwd, and one `--check format` (renamed to `--check fmt`,
  which prints the exact rename inline) — the tool's own redirect message worked as
  designed, no doc gap.
- orchestrator action: `take CtYH_Gmrg --session build-CtYH_Gmrg-5c8fc82c --pr 1719`
  (this time correctly reusing the agent's own label — see the reconciliation entry
  above) — now `awaiting review`. `fs.visit`'s spec-vs-truth discrepancy is real but
  self-resolved within the diff per the item's own instructions ("build a correct,
  unit-tested `return_slots`"); nothing further to file.

## candidates
- none passing the spec bar this pass. Deferred, not lost: the two pre-existing
  unparented triage items («KGOw_xnx8» friction: 2026-09-05 work9-routine,
  «rzSb_Hy5t» resolution-supersession phrasing as a duplicate signal) were left
  untouched — spare width went to the wave (7 disjoint builds filled the doing
  bound to 8/10 with «KYPX_s06P» already occupying one slot) rather than
  triage/decompose actions this pass; a future pass should attach or compare them.
