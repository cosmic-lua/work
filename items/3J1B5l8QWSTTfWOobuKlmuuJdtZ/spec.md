## Evidence

An empirical investigation (real repo clone, real `--make fetch` into
an empty `o/`, real cold `--make build`, two independent reproductions)
found the cold-build staging trap AGENTS.md documents has a precise,
narrower mechanism than its own prose states, split across two
independent code paths:

**Path A — safe.** Every real place the build graph compiles or
type-checks a tree file explicitly passes `--include-dir .` FIRST:
`embed/cosmic.mk:130,139` (`compile`/`compile-batch` recipes),
`_make/check.tl:154` (`check_files`), `_make/closure.tl:156-158` (the
generator-closure mini-graph). `cosmic.teal.compile/check/*`
(`cosmic/teal.tl:96,109,123,136`) route through
`engine.merge_include_dirs` (`cosmic/_teal_engine.tl:360-373`), which
puts caller-supplied dirs ahead of defaults — so "." wins wherever it
is passed. A genuine cold build of a record-field widening on a module
reached only through this path (`cosmic/doc/types.tl`, reached via
`cmd/cosmic/embed_gen.tl`'s spawned generator child, which gets
`--modules <manifest>` on its own argv per `_make/closure.tl:75` /
`_make/generate.tl:75-84` and therefore resolves through
`cosmic/searcher.tl`'s tree-first Layer 3 searcher,
`searcher.tl:226-456`) does NOT fail.

**Path B — the real exposure.** A bare `require()` of an uncompiled
`.tl` module made by the TOP-LEVEL `--make` process itself, before the
graph has compiled anything, goes through `cosmic/searcher.tl`'s
always-installed Layer 1 (`cosmic_tl_searcher`/`search_with`,
`searcher.tl:78-125`, installed by every invocation via
`cmd/cosmic/main.tl:27-40`). Layer 1 calls
`teal.search_module`/`teal.compile_cached` with NO `include_dirs`
argument at all, so `merge_include_dirs(nil)` falls through to
`default_include_dirs()` alone (`_teal_engine.tl:76-86`):
`{o/_types/types_gen, /zip/.types, /zip/.tl, /zip}` — `.` (the live
tree root) is never in this list. Layer 3 (the tree-first searcher)
only activates when the process's own argv carries `--modules
<manifest>` (`install_argv_manifest`, `main.tl:30`) — which a spawned
generator child receives but the top-level `bin/cosmic --make <verb>`
invocation a human or agent types never does. `searcher.tl:415`'s own
doc comment states this design point directly: "a child with no
manifest is an ordinary cosmic, which is what a hand-run script is."

This exactly explains why PR #1775's arity widening on `_cli/lint.tl`
(needed to bootstrap `--make` itself, required raw by the top-level
process before anything compiles) failed a REAL cold
`bin/cosmic --make build` immediately, while an equivalent widening on
`cosmic/doc/types.tl` (reached only inside a spawned, manifest-bearing
generator child) does not. The exposure is real but narrow: it is
specifically the set of modules the top-level `--make` process's own
bootstrap chain reaches via bare `require()` before the build graph
exists to compile anything — `_cli/lint.tl`, `_cli/main_handlers.tl`,
`_make/root.tl` and whatever they transitively require at that point.

## Change

Close the Path B gap for the top-level `--make` process specifically,
without touching Layer 1's behavior for an ordinary hand-run script
(`bin/cosmic some_script.tl`), which must keep resolving against the
pin's shipped copies exactly as it does today — a plain script has no
project-root concept of its own to prefer.

As soon as `--make`'s own dispatch determines the project root (in
`_make/root.tl`, at the point `--make` recognizes itself as a `--make`
invocation rather than an ordinary script run), install the same
Layer-3 tree-first searcher a spawned generator child gets — a minimal
manifest naming just the discovered root, no closure computation
needed (`tree_searcher`'s general tree-relative fallback at
`searcher.tl:392-397` already covers a bare root with no explicit
module list). Every subsequent bare `require()` inside the SAME
top-level `--make` process then resolves tree-first, closing the
exposure at its source rather than requiring every individual
compile/check call site to remember `--include-dir .` (Path A's
existing, easy-to-forget-in-a-new-call-site pattern).

Document the change inline rather than as a separate `decide`-skill
record (explicit instruction — do not open a new ADR for this): update
AGENTS.md's "The cold-build rule" section to state the corrected,
narrower mechanism (Path A vs Path B, which modules are actually
exposed) in place of the current, broader-sounding "an arity widened
on one side of a call between two modules the pinned release already
ships stages the same way" — and note that after this change, the
remaining exposure is confined to whatever the top-level `--make`
process's own bootstrap chain still reaches before this searcher
installs (name that boundary precisely, e.g. `_make/root.tl` itself
and anything it requires ahead of installing the searcher). Update
`_build/coldbuild_test.tl`'s synthetic simulation and doc comment to
match the new, narrower real exposure once this lands (coordinate with
the sibling item fixing that test's staleness gap, if both are in
flight at once — this item's AGENTS.md/doc update takes precedence on
any wording conflict, since it describes the mechanism after the fix).

## Non-goals

No change to Layer 1's behavior for a hand-run script outside `--make`
— it must keep resolving against the pin's shipped copies, since a
plain script has no project root of its own to prefer over the pin
(this is `searcher.tl:4-8`'s and `:415`'s stated design, not a bug).
No change to what the pin ships or how `fetch`/pins work. No attempt
to eliminate `_build/coldbuild_test.tl` — even after this fix, keep it
as the gate against any remaining exposure in `--make`'s own bootstrap
chain (whatever it still requires before the searcher installs). No
separate `decide`-skill record — document the corrected invariant in
AGENTS.md as part of this change instead.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

A record-field or arity widening on `_cli/lint.tl` or
`_cli/main_handlers.tl` (or another module reached by `--make`'s own
bootstrap chain after the tree-first searcher installs) no longer
fails a real `bin/cosmic --make build` from a genuinely empty `o/`
(fetch + build) — verified by reproducing PR #1775's original failing
case and confirming it now passes — while `bin/cosmic some_script.tl`
(an ordinary hand-run script, not `--make`) is confirmed unchanged:
it still resolves a `require()` of a pin-shipped module against the
pin's embedded copy, not the live tree, exactly as before. AGENTS.md's
cold-build section states the corrected mechanism and the remaining
boundary.
