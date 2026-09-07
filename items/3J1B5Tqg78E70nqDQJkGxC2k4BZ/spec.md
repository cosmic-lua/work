## Evidence

`«fqv3_oO2R»` (not-planned, superseded by this item and `«sibling item
b»`) started from an incomplete premise: that widening a record's
field set on an already-shipped module (`cosmic/doc/types.tl`'s
`ModuleDoc`, from `«t5hA_ZnKG»`) fails a REAL cold build the same way
PR #1775's arity widening did. A follow-up investigation (empirical:
cloned the repo, reverted `«t5hA_ZnKG»`'s fix, ran a genuine
`--make fetch` into a genuinely empty `o/`, then `--make build`) found
this false — a real cold build of the widened `ModuleDoc` PASSES,
because `cosmic/doc/types.tl` is only ever `require()`d from inside a
spawned generator child (`cmd/cosmic/embed_gen.tl`'s payload
generation), which gets `--modules <manifest>` on its own argv
(`_make/closure.tl:75`, `_make/generate.tl:75-84`) and therefore
resolves `require()` through `cosmic/searcher.tl`'s tree-first Layer 3
searcher (`searcher.tl:226-456`), not the pin's embedded snapshot.

What DID (and, per this session's report, should) catch the widening
immediately is `_build/coldbuild_test.tl` itself — an ordinary
`*_test.tl` that runs on every `--make test`/`--make ci`, warm or
cold, because it builds its own synthetic generation-1 simulation
(`check_generation_1`, lines 82-94: a deliberately pessimistic
`--include-dir /zip/.tl --include-dir . --include-dir
o/_types/types_gen` ordering, over-approximating the worst case rather
than modeling any single real code path). But in this session's actual
run, the FIRST `bin/cosmic --make ci` after widening `ModuleDoc`
passed clean; only a SECOND run (and, separately, a genuine cold
rebuild) caught it. That gap — a test that is supposed to fire on the
very edit that introduces the problem, firing one run late instead —
is the concrete, fixable bug this item targets.

`_build/coldbuild_test.tl`'s own header declares its inputs via
`--- reads:` (per AGENTS.md's "A test that reads a file the graph
cannot see" convention) at a coarse, directory-level granularity:
`3p _build _cli _docs _eval _fuzz _make _perf _tool _types cmd cosmic
o/bootstrap/cosmic o/_types/types_gen`. The runner "re-records the
result when that file changes" — for a whole tree listed this coarsely,
verify whether an edit to a single file under one of those trees
(e.g. `cosmic/doc/types.tl`) is reliably treated as "that file
changed" by whatever staleness key the runner actually hashes (a
directory mtime? a full-tree content hash? something narrower that
missed this specific file?), or whether there is a real caching hole
that let a stale PASS survive one full `--make ci` run after a
relevant edit.

## Change

1. Reproduce the staleness gap directly: widen a record field on a
   module reached only via a spawned generator child (mirroring
   `ModuleDoc`), run `bin/cosmic --make ci` ONCE from a warm `o/`, and
   determine whether `_build/coldbuild_test.tl` fires on that first
   run or requires a second. If it fires immediately, the gap does not
   reproduce in isolation — narrow the Evidence to whatever condition
   in the original session actually caused the one-run delay (a
   different file touched in between, a partial `o/` state, an
   unrelated stage ordering) and fix THAT specific condition, or close
   this item with the reproduction attempt recorded if no real gap is
   found.
2. If a real gap reproduces: fix `_build/doc_symbols_test.tl`-style
   `--- reads:` staleness tracking (or whatever the actual mechanism
   turns out to be) so `_build/coldbuild_test.tl` invalidates and
   re-runs on any edit under the trees it declares, not just some of
   them.
3. Separately, regardless of (1)'s outcome: `_build/coldbuild_test.tl`'s
   own doc comment currently describes its mechanism as "generation 1
   resolves a tree module's requires against [the pin's] copy... before
   ever reading them off disk" as if this applied uniformly to every
   tree module. It does not — only modules reached by `--make`'s own
   bootstrap chain before compilation (`_cli/lint.tl`,
   `_cli/main_handlers.tl` and similar) are exposed this way in a REAL
   build; the test itself is a deliberately pessimistic superset
   simulation that also flags modules (like `cosmic/doc/types.tl`)
   which a real cold build would not actually break. Correct the
   comment to state this precisely: what real exposure the test is
   modeling, and that it is intentionally conservative rather than a
   faithful model of the actual risk surface.

## Non-goals

Not closing the actual exposure (bare `require()` from `--make`'s own
bootstrap chain resolving through the pin's snapshot with no
`--include-dir .`) — that is the separate, architectural item this
session also filed (closing `cosmic/searcher.tl`'s Layer 1 gap for the
top-level `--make` process). This item is only about the ratchet
test's own timeliness and the accuracy of its documentation.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

A record-field widening on a module reached only via a spawned
generator child is caught by `_build/coldbuild_test.tl` on the FIRST
`bin/cosmic --make ci`/`--make test` run after the edit, from a warm
`o/`, with no second run or cold rebuild required — verified by a
fixture or a documented manual reproduction in the PR body — and the
test's own doc comment accurately describes what real exposure it
approximates (the bootstrap-chain Path B case) versus what it flags
conservatively beyond that.
