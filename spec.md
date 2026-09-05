## Evidence

`q0zL_uDdq` ("casts: _make's verb registry returns a typed Verb, closing
the 8 dynamic-name-lookup sites") specifies closing all 8
`dynamic name lookup` sites in one PR: 7 in `_make/init.tl` (via a new
`policy.must_verb` helper) and 1 in `cosmic/searcher_test.tl:57-58`.

A builder verified the 7 `_make/init.tl` sites close cleanly:
`policy.must_verb(by_name, name)` (an `assert`-backed helper on
`PolicyModule`, D30's infallible-by-type contract boundary) type-checks
and keeps `_make/init.tl` under the 500-line cap.

The 8th site does not close as specified. The spec's own probe
(`for _, s in ipairs(package.searchers) do local ok, why = pcall(s,
"x") end` → "Type check passed") is insufficient: it never exercises
`why` the way the actual test does. Reproduced against the pinned
checker with the cast removed:

    cosmic/searcher_test.tl:58:19: warning: why (of type function(? string, ? <any type>): <any type>) can never be a string
    cosmic/searcher_test.tl:58:19: error: why (of type function(? string, ? <any type>): <any type>) can never be a string
    cosmic/searcher_test.tl:58:29: error: cannot resolve a type for why here

Root cause: the pinned tl's own builtin declares `package.searchers` as
`{ function(string): (function(?string, ?any): any, any) }`
(`o/3p/tl/tl.tl:337`, and byte-identically `o/3p/tl/tl.lua:337`) —
every searcher entry is typed to return exactly `(loader-function,
any)` on a call, with no `string` alternative. But this test's whole
point is that a *declining* searcher returns a bare `string` instead
of a loader — a real, working Lua/tl idiom the builtin type doesn't
model. No cast-free rebinding both type-checks and preserves the real
runtime semantics (a captured third return value type-checks but binds
the wrong slot; wrapping in an inline `pcall` fails with "excess
return values, expected 1, got 2"). Fixing the underlying gap means
patching tl's builtin `package.searchers` annotation via
`3p/tl/tl_patch/`.

**A fix was verified**: adding a `| string` union arm to the first
element of the return tuple type-checks clean and preserves semantics.
Probe (read-only: a scratch copy of `o/3p/tl/tl.lua` with just this
one-line edit, loaded into `package.loaded["tl"]` before
`require("tl")` — the same technique `_make.patch`'s `reverse` probe
uses, so the unpack directory under `o/3p/tl` is never written):

    find:    searchers: { (function(string): (function(? string, ? any): (any), any)) }
    replace: searchers: { (function(string): (function(? string, ? any): (any) | string, any)) }

Checking the real loop from `cosmic/searcher_test.tl:52-63` (cast
removed) against the patched builtin, via `tl.check_string`:

    syntax_errors: 0
    type_errors: 0
    warnings: 0

against the unpatched builtin, the same snippet reproduces the exact
failure above (`type_errors: 2`, `warnings: 1`, same messages). The
union also keeps every other live consumer of the builtin type
type-checking clean under the same probe: `cosmic/searcher_test.tl:96`
and `cosmic/searcher_tree_test.tl:132`'s `local s: function(string):
(any, any) = package.searchers[seat]` re-typing, and
`cosmic/searcher.tl`'s `table.insert(package.searchers, ...)` of a
plain `function(string): any, any` — all 0 syntax/type errors.

`3p/tl/tl_patch/narrow.tl` is 467 lines against the 500 cap (`wc -l
3p/tl/tl_patch/narrow.tl`) — 33 lines of headroom, not enough for a new
paired entry plus its note; the other patch files are thematically
unrelated. A new topically-named file is the fit, matching how the
directory already splits by theme (`ast_cache.tl`, `cast.tl`,
`closure.tl`, `enum.tl`, `for_control_var.tl`, `narrow.tl`).

**The above probe is necessary but not sufficient — the class of gap
this refinement exists to fix.** A builder implemented the ORIGINAL
one-PR spec exactly (the patch file above, plus removing the cast in
`cosmic/searcher_test.tl` and the baseline/tsv/docs reconcile steps)
and hit `_build/coldbuild_test.tl`'s guard: generation 1 of every build
type-checks the WHOLE tree using the PINNED release's own embedded
`tl` checker (`o/bootstrap/cosmic`, invoked with `--include-dir .` so
it resolves MODULES from the tree while the CHECKER stays the pin —
`_build/coldbuild_test.tl:12-19`'s doc comment states this exactly),
not the freshly-patched `o/3p/tl/tl.lua`. The pinned release
(`bin/cosmic.pin`, currently `2026-09-04-5d5dc3a`) predates this
patch, so gen1 fails on `cosmic/searcher_test.tl:58` with the exact
error reproduced above — the cast-free rewrite can never reach gen1's
checker in the same PR that adds the patch. `AGENTS.md`'s Build System
section states the required staging: "a source that needs the tree's
own checker (a new narrowing rule, a new patch entry) passes the
converged `--make ci` and fails only a cold build... Such a change
stages behind a release and pin bump: land the checker first, bump
`bin/cosmic.pin` to a release carrying it, then land the code that
needs it." The original spec conflated both halves into one PR, which
cannot pass a cold build as written.

This repo already has a working precedent for exactly this split, on
a different pin: `keP3_sWNy` (`cosmic-lua/cosmopolitan`-side
annotation) landed alone, and `vBk9_UxhS` (the `cosmic-lua/cosmic`-side
pin bump + cast removal, `blocked_by keP3_sWNy`) was filed for the
half that needs a release first. This item mirrors that shape, except
both halves are `cosmic-lua/cosmic`-internal (the patch and the pin
that must carry it are the same repo's own pin to itself).

**This refinement verified the patch-file-ALONE half does not itself
trip the cold-build rule.** In a scratch clone of the tree at the
current tip (not the builder's worktree — read for reference only),
added ONLY `3p/tl/tl_patch/declining_searcher.tl`, with
`cosmic/searcher_test.tl` left completely unmodified (cast still in
place):

    o/bootstrap/cosmic --check types --include-dir . --include-dir o/_types/types_gen \
        3p/tl/tl_patch/declining_searcher.tl
    Type check passed: 3p/tl/tl_patch/declining_searcher.tl

    o/bootstrap/cosmic --check types --include-dir . --include-dir o/_types/types_gen \
        cosmic/searcher_test.tl
    Type check passed: cosmic/searcher_test.tl

Then the full gen1 sweep exactly as `_build/coldbuild_test.tl` composes
it (every `.tl` under `3p _build _cli _docs _eval _fuzz _make _perf
_tool _types cmd cosmic`, testdata excluded — 625 files with the new
one added) under the same pinned bootstrap: exit 0, "Type check
passed" on all 625, including the new file. Then the actual guard
test itself, via the tree's own build:

    o/bin/cosmic --make test _build/coldbuild_test.tl
    ✓ _build/coldbuild_test.tl (1 test functions)  18701ms
    test: PASS (1 file)

**Running the change as it will actually land surfaced one real gap
the original spec's `## Change` missed.** After `bin/cosmic --make
fetch` (confirmed the patch applies: `o/3p/tl/tl.lua:337` and
`tl.tl:337` both now read the `| string` arm), a full `bin/cosmic
--make ci` FAILED at the coverage stage:

    coverage ratchet: 3p/tl/tl_patch/declining_searcher.tl: not in baseline (new file? run 'cosmic --make coverage --baseline' and commit)
    coverage ratchet: 1 problem(s); if the decline is intended, run 'cosmic --make coverage --baseline' and commit the result
    coverage: FAIL (288 files)
    ci: FAIL (coverage)

Every existing `3p/tl/tl_patch/*.tl` file already carries a
`.cosmic-coverage` row (`ast_cache.tl`, `cast.tl`, `closure.tl`,
`enum.tl`, `for_control_var.tl`, `narrow.tl`, all `{covered = 0, total
= 1}` — `grep -n tl_patch .cosmic-coverage`); the new file needs the
same row, added by hand per `AGENTS.md`'s Testing section ("Move the
one row your change actually affects by hand-editing its
`covered`/`total` pair in `.cosmic-coverage` directly"). Adding

    ["3p/tl/tl_patch/declining_searcher.tl"] = {["covered"] = 0, ["total"] = 1},

(alphabetically between `closure.tl` and `enum.tl`, matching the
existing rows' shape) and re-running:

    3338 tests: 3338 passed
    coverage: read 1046 .cov files
    coverage ratchet ok
    coverage: PASS (288 files)
    ci: PASS (5 stages)

with `cosmic/searcher_test.tl`'s cast confirmed untouched throughout
(`grep -n "cast:" cosmic/searcher_test.tl` still shows the line at
every step above).

Because this item now lands only the patch file — the
`cosmic/searcher_test.tl` cast, and the `_build/casts_baseline.tl` /
`docs/design/cast-sites.tsv` / `docs/design/casts.md` reconcile steps
that follow from removing it, are deferred to `zs1K_cWnY` ("casts:
land searcher_test.tl's cast removal once the declining-searcher patch
is pinned"), `blocked_by` this item — `docs/design/cast-sites.tsv`'s
`dynamic name lookup` class keeps ALL 8 rows after THIS item lands
(not 7): the `cosmic/searcher_test.tl` row is untouched here, and the
7 `_make/init.tl` rows are `q0zL_uDdq`'s separate scope. Likewise
`docs/design/casts.md`'s `### dynamic name lookup` prose is left
unedited here (still reading the stale "wants a declared record"
line) — correcting it is bundled with `zs1K_cWnY`'s cast removal, so
the prose is rewritten once, describing the site's actual FINAL state
rather than a half-landed one.

## Change

- New file `3p/tl/tl_patch/declining_searcher.tl` with two entries (the
  `tl.lua`/`tl.tl` pairing this directory already uses for a builtin-type
  fix, e.g. `narrow-assert-decl` / `narrow-assert-decl-tl-tl` in
  `3p/tl/tl_patch/narrow.tl`):

  ```teal
  return {
    ["declining-searcher-package-searchers"] = {
      file = "tl.lua",
      note = "a declining searcher returns a bare string, not a loader; the builtin type had no arm for it",
      find = [=====[      searchers: { (function(string): (function(? string, ? any): (any), any)) }
  ]=====],
      replace = [=====[      searchers: { (function(string): (function(? string, ? any): (any) | string, any)) }
  ]=====],
    },
    ["declining-searcher-package-searchers-tl-tl"] = {
      file = "tl.tl",
      note = "a declining searcher returns a bare string, not a loader; the builtin type had no arm for it (Teal ground truth)",
      find = [=====[      searchers: { (function(string): (function(? string, ? any): (any), any)) }
  ]=====],
      replace = [=====[      searchers: { (function(string): (function(? string, ? any): (any) | string, any)) }
  ]=====],
    },
  }
  ```

  Both `find` strings occur exactly once today in their respective
  files (verified above); `_make/patch.tl`'s apply enforces that on
  every fetch regardless.
- `.cosmic-coverage`: add
  `["3p/tl/tl_patch/declining_searcher.tl"] = {["covered"] = 0, ["total"] = 1},`
  alongside the other `3p/tl/tl_patch/*.tl` rows (alphabetically
  between `closure.tl` and `enum.tl`) — required, or the coverage
  stage refuses the new unbaselined source (verified above).
- Run `bin/cosmic --make fetch` so the new patch applies into
  `o/3p/tl/tl.lua` and `o/3p/tl/tl.tl` — required before any check or
  build observes it (`3p/tl/tl_patch/*.tl` entries apply on fetch, not
  on write).
- `cosmic/searcher_test.tl` is left COMPLETELY UNTOUCHED — the
  `-- cast:` comment and the cast at line 57-58 both stay exactly as
  they are. Gen1 still type-checks this file against the OLD pinned
  checker (no `| string` arm) even in this same PR that adds the
  patch, since the pin itself does not move here; removing the cast is
  `zs1K_cWnY`'s scope, gated on a release + pin bump.
- `bin/cosmic --make ci` ends `ci: PASS` — with the patch present,
  applied via fetch, and the cast still in `cosmic/searcher_test.tl`
  (verified above).

## Non-goals

The 7 `_make/init.tl` dynamic-name-lookup sites, `policy.must_verb`,
and the tsv class reaching zero rows are `q0zL_uDdq`'s scope —
untouched here regardless of landing order between the two items.

Removing `cosmic/searcher_test.tl`'s cast, the `_build/casts_baseline.tl`
/ `docs/design/cast-sites.tsv` / `docs/design/casts.md` reconcile steps
that follow from it, and the `docs/design/casts.md` prose correction
are `zs1K_cWnY`'s scope — not resolvable until a cosmic release exists
whose commit descends from this item's merge and `bin/cosmic.pin` is
bumped to it, so they are deliberately not attempted here even though
their content is already known (carried verbatim into `zs1K_cWnY`'s
spec).
