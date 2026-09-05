# friction: 2026-09-05 work9-c (autonomous-loop continuation of /work 9 --routine)

## orchestrator

- goal: after the "/work 9 --routine" pass proper ended (both its items
  merged, its own friction log filed), decide what to do when a generic
  "autonomous loop check" tick fired next, framed around PR-maintenance/
  conversation-continuity language that doesn't literally describe a
  board-driven session.
  actually happened: treated it as authorization to continue the
  standing `/work` loop (the scheduling task that started this session
  was explicitly "/work 9 --routine", and the skill's own doctrine
  describes repeated bounded passes under `/loop` as the norm) rather
  than stopping cold — triaged the newly-filed friction log
  (`HWDX_5ZOC`, itself a recursive instance of the same pattern
  `mms6_eoOB` established at the start of this session), then pulled
  the next highest-priority item.
  contributed: the generic autonomous-loop-check template and the
  `/work` skill's own standing-loop doctrine are two different
  mechanisms layered on the same `ScheduleWakeup`/`<<autonomous-loop-
  dynamic>>` primitive, with no explicit statement of which one
  governs when both are in play.
  improvement: none actionable from inside this session — flagging
  only as context for why this log exists as a THIRD friction file in
  one calendar day's single continuous session, rather than a cleaner
  one-pass-one-log shape.

## refine 1Lhz_38Wt (general-purpose, background) — spec accepted, 668746ms wall, 60 tool calls

Refined the top of the backlog after triage cleared. No friction
distinct from the ordinary refine pattern already logged in
`friction-2026-09-05-work9-b.md` — the one new wrinkle (a builder
CLI-handle typo, `1KcWnY` vs. `zs1K_cWnY`) belongs to the NEXT agent's
section below, not this one; this refiner correctly decided the
7-of-8 split and identified the tl_patch fix, but did NOT catch that
the resulting spec would fail the cold-build rule — that gap only
surfaced when a builder actually tried to land it (see next section).

## build 1Lhz_38Wt (general-purpose, background) — STOPPED, no push, 373s wall, 23 tool calls

- goal: build the refined spec exactly as written (patch file + cast
  removal + baseline/tsv/docs reconcile, one PR).
  actually happened: `bin/cosmic --make ci` failed at the BUILD stage,
  not a later gate — generation 1 tried to type-check the whole tree
  with the PINNED release's own embedded `tl` checker (predating the
  new patch) and failed on `cosmic/searcher_test.tl:58` with the exact
  error the item's own Evidence had already reproduced against the
  UNPATCHED builtin. Correctly recognized this as `_build/
  coldbuild_test.tl`'s documented mechanism (`AGENTS.md`'s "Build
  System" section — "a source that needs the tree's own checker...
  fails only a cold build... stages behind a release and pin bump"),
  stopped without pushing, left the diff committed-but-unpushed on the
  item branch per the builder brief's own instruction, and reported
  the exact blocker with commands and output.
  contributed: the refiner's own verification technique (an in-process
  `package.loaded["tl"]` probe, imitating `_make.patch`'s `reverse`
  probe) never exercises gen1's actual mechanism (the PINNED RELEASE
  BINARY as the checker, not the freshly-patched `o/3p/tl/tl.lua`), so
  a refiner cannot catch this class of gap no matter how careful the
  probe is — only an actual `bin/cosmic --make ci`/`--make build` from
  a state resembling a fresh clone catches it, which is exactly what
  builder step 1 asks for and exactly what this builder did correctly.
  improvement: this is the second time in one session a spec involving
  `3p/tl/tl_patch/` conflated a new checker capability with code that
  depends on it in one PR (the coverage-row gap on `keP3_sWNy`'s sibling
  patch item was a smaller instance of the same "refiner probe can't
  see what only a real build shows" class). `gitboard help bar`'s
  measured-not-inferred rule already covers BEHAVIOURAL claims needing
  a command and output — it does NOT yet warn that a `3p/tl/tl_patch/`
  item's own refiner-time verification technique (necessarily an
  in-process probe, since the item isn't committed yet) structurally
  cannot exercise the cold-build path, so refining such an item without
  ALSO staging a real `bin/cosmic --make build` dry run (as this
  session's follow-up refiner then did, in a throwaway scratch clone)
  is incomplete verification by construction. Worth a `casts.md`/`bar`
  callout: "an item touching `3p/tl/tl_patch/` needs its Change
  verified with a real cold-adjacent build, not just an in-process
  probe, because the in-process technique cannot see the pin boundary."
  Stays here for triage — doc-level but now TWO independent hits this
  session, a real recurring pattern.

## orchestrator (continued) — reconciling a worker-side stop for an item-side gap

- goal: reconcile the stopped build (no PR, no push) per `gitboard help
  system`'s two-exits-from-doing rule.
  actually happened: attempted a bare `gitboard drop 1Lhz_38Wt --why
  ...` first (treating it as worker-side); refused: `gitboard-drop:
  REFUSED: ... is build-1Lhz_38Wt-2305d922's live claim — the builder
  drops their own work; abandon a dead session's with --force`. Retried
  with `--force`; succeeded, but printed a standing reminder: "a bare
  drop says the item is fine; if it cannot proceed, `new` the question
  and `block` first." Read this correctly as a genuine item-side gap
  (the spec's SHAPE was wrong, not just late/wrong numbers), but judged
  that the doctrine's literal "new the question, block ID on it, then
  drop" ritual doesn't fit a case where the RESOLUTION is already known
  (re-scope, per direct precedent from `keP3_sWNy`/`vBk9_UxhS` earlier
  this same session) and the ORIGINAL item itself isn't blocked on
  anything once re-scoped — only a NEW sibling item is. Proceeded by
  filing the sibling item and re-refining the original directly, which
  worked, but the doctrine text doesn't explicitly address this "the
  question already has a known answer, and it's a re-scope not a
  standing question" shape.
  contributed: `gitboard help system`'s two-exits framing (`new` the
  question / `block` / `drop`) reads as written for a genuinely OPEN
  question needing a decision from elsewhere, not for "the item's
  Change was simply wrong and needs re-refining, with a clean split
  filed alongside it" — a shape this session hit twice now (this item,
  and less severely `keP3_sWNy`'s over-broad sibling `vmX5_zQH2` noted
  in the prior friction log) without ever actually using `block`.
  improvement: `gitboard help block`/`help system` could name this
  shape explicitly as a THIRD pattern distinct from "open question
  blocks the item": a spec whose Change is simply wrong is fixed by
  refining it directly (no `block` needed) even when a NEW sibling item
  is split off in the process, since the sibling holds ITS OWN
  `blocked_by` edge, not this item's. Stays here for triage — doc-level,
  two hits this session (one explicit, one implicit).
- goal: re-take the re-scoped item for a fresh build attempt.
  actually happened: minted `build-1Lhz_38Wt-r2-2305d922` by the same
  habit already flagged once this session for review sessions (see
  `friction-2026-09-05-work9-b.md`'s "self-inflicted session-name
  mismatch" entry) — `gitboard brief builder 1Lhz_38Wt` immediately
  after confirmed the plain `build-1Lhz_38Wt-2305d922` is what it
  actually emits, with no round-awareness. Caught before spawning
  (one `brief` call), corrected via drop+re-take rather than text
  editing this time (cheaper since no agent was spawned yet). THIRD
  occurrence of the identical habit (review round 2 earlier, now build
  round 2) — no longer a one-off, a genuine gap in how I derive claim
  session names after ANY drop/re-take cycle, not specific to review.
  improvement: escalating the earlier candidate — `gitboard help
  orchestrate` should state plainly that EVERY minted claim name
  (build, research, review, refine, decompose) is deterministic from
  `<kind>-<handle>-<orch8>` alone with no round/attempt component, so
  an orchestrator re-claiming after any drop, bounce, or rework should
  always re-run `brief`/read the mint line fresh rather than inventing
  a disambiguating suffix from habit. Filed as a candidate below (still
  doc-level, but now 3 hits, all in the SAME hour).
- goal: discard the first build attempt's stale worktree/branch
  (superseded by the re-scoped spec) before creating a clean one.
  actually happened: `git worktree remove --force` +
  `git branch -D` on the local, unpushed, superseded branch worked
  cleanly in one shot — no friction, noted only because it's a
  destructive-looking operation (branch delete) that's actually safe
  here (never pushed, never shared, explicitly superseded).

## build 1Lhz_38Wt-r2 (general-purpose, background) — PR #1727 opened, 271750ms wall, 28 tool calls

Clean build, matching the re-scoped spec exactly; mutation-tested the
new coverage-ratchet row by removing it and confirming the ratchet
refuses. No friction reported beyond noting `--make fetch` itself
triggers a full rebuild (not just a patch-and-download), costing a
few minutes of wait with no tool-call cost — consistent with
`AGENTS.md`'s "generators run before the graph" convention, just not
explicitly called out as something a fresh builder should expect to
wait through.

## review 1Lhz_38Wt (general-purpose, background) — accept, auto-merge enabled, 273851ms wall, 22 tool calls

Independently reproduced the exact cold-build failure via mutation
test (temporarily re-applying attempt 1's mistake — removing the cast
— and confirming `_build/coldbuild_test.tl` fails with the identical
error), then restored and confirmed clean. This is the single most
on-point mutation test of the whole session: it tests the SPECIFIC
re-scope rationale, not just an arbitrary guard. No friction beyond
the now-familiar `gh` CLI absence (immediately worked around via the
GitHub MCP tools, zero cost beyond one failed exploratory call).

## candidates

- an item touching `3p/tl/tl_patch/` needs a real (not in-process-
  probe-only) cold-adjacent build as part of its refinement-time
  verification, since the in-process technique cannot see the pin
  boundary — two independent hits this session (the coverage-row gap,
  and this item's full build-stage failure). Stays here for triage:
  `gitboard help bar` or `casts.md`, doc-level.
- `gitboard help system`'s two-exits-from-doing framing should name a
  third pattern: a wrong-shaped Change with an ALREADY-KNOWN fix is
  refined directly (no `block` needed), even when a new sibling item
  is split off — the sibling carries its own `blocked_by` edge, this
  item does not need one. Stays here for triage, doc-level.
- (escalated from `work9-b`, now 3 hits total) `gitboard help
  orchestrate` should state explicitly that every minted claim name is
  deterministic from `<kind>-<handle>-<orch8>` with no round/attempt
  component, so re-claiming after ANY drop/bounce/rework should re-run
  `brief`/read the mint line rather than inventing a disambiguating
  suffix. Stays here for triage — a gate (`take` refusing an
  orchestrator-invented suffix outright, or `brief` accepting `--round
  N` and naming it explicitly) would outrank the doc fix per `help
  bar`'s own ranking, but is out of scope for this session to build.

## pass summary

Continued the standing `/work` loop past its first bounded pass: closed
the recursive friction-log triage item, pulled `1Lhz_38Wt` (the
`package.searchers` decline-shape tl_patch, the next highest-priority
bar-missing item), and drove it through a real spec-vs-reality gap —
a first build attempt hit the cold-build/pin-bump staging rule
(`AGENTS.md`'s documented convention, already precedented once this
session by `keP3_sWNy`/`vBk9_UxhS`), which a refine agent then
resolved by re-scoping the item to land only the safe half and
splitting the deferred half into a new `blocked_by` sibling
(`zs1K_cWnY`). A second build attempt on the corrected spec landed
cleanly (PR #1727), reviewed accept with a mutation test that
specifically reproduced the original cold-build failure to confirm the
guard, merged, and closed. Board ends this continuation at 0/10 doing,
0 triage, 3 items merged today across this session's two friction-log
spans (`keP3_sWNy`, `LqNF_WKnL`, `1Lhz_38Wt`), one new follow-up item
filed and correctly blocked (`zs1K_cWnY`, alongside `vBk9_UxhS` from
the prior span). No countermeasure here reached the spec bar (all
doc-level); this log enters triage unparented for the next pass.
