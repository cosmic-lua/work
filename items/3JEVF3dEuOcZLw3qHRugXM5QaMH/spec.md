# fence: a build nested four levels deep fails with `No rule to make target`, three levels is fine

Source: cosmic-lua/cosmic#839 (open, no board item)

## Goal

Know whether the nested-fence ceiling found while writing the make
resolution gates (three levels of `record` intersecting Landlock
policies works, four fails with a misleading `No rule to make target`)
is intrinsic to stacking Landlock rulesets or an artefact of how each
nesting level derives its own grants — and either lift it, or turn the
failure into an honest "fence denied this read" message instead of a
build-graph error that sends a reader to the wrong half of the system.
This is scoped as a research item first: the fix in either direction
depends on which cause it turns out to be, and nobody has yet run the
experiment that tells them apart.

## Evidence

The design doc this issue was filed alongside is unchanged on this
question. `docs/design/make/resolution.md`'s "Open" section still
carries the exact finding, word for word:

```
$ grep -n "How deep a fenced build nests" docs/design/make/resolution.md
- **How deep a fenced build nests.** Found while writing the gates and
$ sed -n '/How deep a fenced build nests/,/wants its own change/p' docs/design/make/resolution.md
- **How deep a fenced build nests.** Found while writing the gates and
  recorded rather than dropped: a `--make` build run from a test that is
  itself run by a nested `--make test` — four levels of `record`, each
  intersecting its parent's Landlock policy — fails in CI with `No rule
  to make target`, while the same build passes standalone and passes
  locally where Landlock does not enforce. Three levels is what
  `_make/fixtures_test.tl` and `_make/build_test.tl` already do and they
  are green, so the limit sits between. The non-inheritance gate asserts
  the mechanism at two levels instead — a grandchild inheriting the
  parent's whole environment still resolves from source, not from the
  parent's build — which is the property that was actually in question.
  The depth ceiling is a fence question and wants its own change.
```

That file was last touched by an unrelated coverage-wording commit,
confirming this section is current and not stale prose predating a
fix:

```
$ git log --oneline -1 -- docs/design/make/resolution.md
2b2002d coverage: --make coverage --min PCT [--min-file PCT] replaces the .cosmic-coverage ratchet and its --baseline (#1778)
$ git show 2b2002d --stat | grep resolution
 docs/design/make/resolution.md                    |   6 +-
```
(a 6-line coverage-terminology diff, not a fence-nesting change; the
mini-graph/seed work that landed *before* this commit — `_make/seed.tl`,
D43 — touched a different "Open" bullet, not this one).

The substitute test the doc describes replacing the 4-level reproducer
is exactly what ships today — a 2-level non-inheritance property, not
a 4-level depth probe:

```
$ grep -n "test_resolution_does_not_inherit" _make/resolution_test.tl
180:local function test_resolution_does_not_inherit()
```
(its own comment, `resolution_test.tl:168-179`, states the property it
actually checks: a grandchild spawned with its own environment must
NOT inherit the parent's build-resolution manifest — not a depth
ceiling.)

No file in the tree targets the 4-level case directly — grep for a
depth-shaped test name or a 4-deep nesting returns nothing:

```
$ grep -rn "four levels\|depth.*fence\|fence.*depth" _make/*_test.tl _cli/*_test.tl
$
```

The fence itself is default-on in this repo's own CI today (not the
opt-in canary phase 1 shipped it behind), so this ceiling sits on the
path every PR's `pr / ci` lane already runs, not an opt-in corner:

```
$ sed -n '46,49p' _cli/driver.tl
local function fence_enabled(): boolean
  return os.getenv("COSMIC_FENCE") ~= "0"
end
```

A live re-reproduction of the 4-level nesting (build a fixture project
inside a test run inside `--make test` run inside another `--make
test`) was not completed in this pass: the existing full-tree
`--make test`/`--make build` invocations in this sandbox each ran past
their own multi-minute budget while investigating this and the other
items in this batch, so the "measured, not inferred" evidence above is
the doc's own recorded finding plus the absence of any newer test or
fix, not a fresh live capture of the failure. A refiner picking this up
should re-run the reproducer named in the issue (`_make/resolution_test.tl`
at commit `2327655` on `claude/module-loading-tree-fgyxte`, before it
was narrowed) fresh, on a clean `o/`, and paste that output before
treating the root cause as settled either way.

## Change

Research item — this is not a code change yet, because which fix is
correct depends on the answer:

1. Reconstruct the 4-level reproducer from the issue (a `--make run`
   invoked from a test that is itself run by a nested `--make test`,
   itself run by an outer `--make test`) as a fixture under
   `_make/testdata/`, gated behind an opt-in env var the way
   `_make/fixpoint_test.tl` gates `COSMIC_FIXPOINT=1` (this reproducer
   is slow and CI-environment-sensitive the same way).
2. At each nesting level, print the effective Landlock ruleset just
   applied (`cosmic.sandbox.apply`'s own enforcement report — see
   `hc6R_jxJB`'s "the enforcement report distinguishes full / degraded
   / skipped" — already carries this) immediately before the failing
   level's own `record` step runs, so the failure is caught with the
   actual policy in hand rather than inferred after the fact.
3. Record the answer as a decision in `docs/decisions/` (a new record,
   per the `decide` skill): either "N is a hard Landlock/kernel ceiling,
   accepted, and `_make` refuses gracefully past it" (naming the kernel
   mechanism — rule-count limit, `landlock_restrict_self` stacking
   depth, or similar) or "the ceiling is an artefact of derivation at
   level K, fixed by `<change>`" — at which point that decision's own
   `## Change`-shaped follow-up is a separate, buildable item.
4. Regardless of which answer, fix the misleading error message: a
   fence denial during a nested build must not surface only as make's
   own `No rule to make target 'o/greet/init.lua'` — that message
   sends a reader to the model/graph half of the system when the fault
   is the fence. Detect the shape (a compile step's recipe failed
   under a fence, then a later target that depended on its output
   reports the generic make error) and prepend a line naming the fence
   as the suspect, in whichever module currently surfaces `run: FAIL
   (N files)` (`_make/stage.tl`'s `verdict`, or the graph-run path that
   calls it).

## Non-goals

- Not deciding the fence grant shape for `run`/the generator mini-graph
  (cosmic-lua/cosmic#837, separate item) — this item is about nesting
  DEPTH, not about what a single level's grant should contain.
- Not lifting the ceiling by guessing at a Landlock syscall limit
  without having measured which level's derivation actually fails.

## Access

- cosmic-lua/cosmic — read+write (the only repo this spec touches).

## Proposed board placement

Parent candidate: `«lei5_yM5b» G4 — zero-config project gates`
(container, `todo`) — same umbrella as #837, since both are about the
fence's behavior under `--make`'s own recursive use of itself, which
is exactly the "gates that do not wedge" territory this container's
existing children (`ngcQ_PoP5` a poisoned `o/bin/cosmic` after a red
gen-2, `PxMM_mVMH` concurrent-build corruption) already cover. No
existing item names fence nesting depth specifically
(`gitboard find "nested build"`, `"landlock nesting"` — no relevant
hits); G2 (`hc6R_jxJB`) was considered for its Landlock-ABI focus but
rejected as parent for the same reason as in #837's spec — its
children are C-binding ABI coverage, not this repo's own recursive
`--make` behavior.
