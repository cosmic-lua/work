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

**Refinement verified a fix**: adding a `| string` union arm to the
first element of the return tuple type-checks clean and preserves
semantics. Probe (read-only: a scratch copy of `o/3p/tl/tl.lua` with
just this one-line edit, loaded into `package.loaded["tl"]` before
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

`docs/design/casts.md`'s `### dynamic name lookup` section currently
reads "The searcher slot wants a declared record and nothing more" —
that resolution was never built and is not what closes it; the
sentence needs to change to match whichever fix actually lands.

Because this item closes only 1 of the class's 8 rows,
`docs/design/cast-sites.tsv`'s `dynamic name lookup` class keeps rows
after this item lands (the 7 in `_make/init.tl`, `q0zL_uDdq`'s scope) —
no zero-row / section-deletion step applies here, unlike a full 8-of-8
close.

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
- Run `bin/cosmic --make fetch` so the new patch applies into
  `o/3p/tl/tl.lua` and `o/3p/tl/tl.tl` — required before any check or
  build observes it (`3p/tl/tl_patch/*.tl` entries apply on fetch, not
  on write).
- `cosmic/searcher_test.tl:57-58`: delete the `-- cast:` comment line
  and change `pcall((s as function(string): any), missing)` to
  `pcall(s, missing)`.
- `_build/casts_baseline.tl`: run `bin/cosmic --make run _build/casts.tl
  --baseline` and commit — this drops the now-zero
  `["cosmic/searcher_test.tl"] = 1` entry.
- `docs/design/cast-sites.tsv`: run `bin/cosmic --make run
  _build/cast_sites.tl --reconcile` — this drops the
  `cosmic/searcher_test.tl	58	dynamic name lookup` row. The class keeps
  its heading and its remaining 7 rows (all `_make/init.tl`), so no
  section-deletion step applies (`_build/cast_sites_test.tl` only
  requires a heading with at least one row, which 7 remaining rows
  satisfy).
- `docs/design/casts.md`: in the `### dynamic name lookup` section,
  replace "The searcher slot wants a declared record and nothing
  more." with "The searcher slot's decline (a bare string, not a
  loader) has no arm in tl's builtin `package.searchers` type; a
  carried `3p/tl/tl_patch/` entry teaches it the union, closing the
  last one."
- `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

The 7 `_make/init.tl` dynamic-name-lookup sites, `policy.must_verb`,
and the tsv class reaching zero rows are `q0zL_uDdq`'s scope —
untouched here regardless of landing order between the two items.
