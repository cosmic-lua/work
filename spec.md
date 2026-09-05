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

## candidates
- none passing the spec bar this pass. Deferred, not lost: the two pre-existing
  unparented triage items («KGOw_xnx8» friction: 2026-09-05 work9-routine,
  «rzSb_Hy5t» resolution-supersession phrasing as a duplicate signal) were left
  untouched — spare width went to the wave (7 disjoint builds filled the doing
  bound to 8/10 with «KYPX_s06P» already occupying one slot) rather than
  triage/decompose actions this pass; a future pass should attach or compare them.
