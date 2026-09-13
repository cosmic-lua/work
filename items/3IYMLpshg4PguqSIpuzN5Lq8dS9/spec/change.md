Add exactly one new tl subtyping rule as a carried patch entry, and
nothing else in the tree that depends on it. No cast site changes in
this PR — see Non-goals for why.

1. **New file `3p/tl/tl_patch/enum.tl`**, in the exact shape of the
   existing `3p/tl/tl_patch/narrow.tl` (module doc comment describing
   the group, `_make/patch.tl` mechanism note, one `return { [name] = {
   file, find, replace, note }, ... }`), one entry:

   - name: `enum-subset-is-subtype`
   - `file = "tl.lua"`
   - target: `TypeChecker.subtype_relations["nominal"]["nominal"]` in
     `tl.lua` (pinned v0.24.8; lands at `o/3p/tl/tl.lua` after
     `bin/cosmic --make fetch`) — the function starting
     `function(self, a, b) local ok, errs = self:are_same_nominals(a, b)`
     around line 9767. After it resolves `ra`/`rb` via
     `self:resolve_nominal`, and before the final `return ok, errs`
     that reports the original mismatch, add: when `ra.typename ==
     "enum"` and `rb.typename == "enum"`, `ra` is a subtype of `rb`
     when every key of `ra.enumset` is also a key of `rb.enumset` (a
     `{string:boolean}` word set, confirmed by its existing use at
     `tl.lua` line ~9811 and ~9896) — return `true` in that case,
     otherwise fall through to the existing `return ok, errs`. This is
     a pure widening (a comparison that used to fail now succeeds in
     one more case, nothing that used to succeed can stop); write the
     `note` field citing this board item and the two commands above.
   - Locate the exact anchor text on the pinned source you fetch — do
     not assume the line numbers here are byte-exact; `_make/patch.tl`
     fails loudly if `find` doesn't match exactly once, which is the
     re-audit signal if it doesn't.

2. **Tests, in `3p/tl/tl_test.tl`** (currently 107 lines, well under
   the 500-line cap), following the file's own
   `tl.process_string(src, false, nil, chunkname)` /
   `result.type_errors` pattern already used by
   `test_new_env_checks_like_the_parse_path`. Three cases, each
   asserting on `#result.type_errors`:
   - a subset enum (word set `{"zlib","gzip","raw"}`) passed where a
     superset enum (`{"zlib","gzip","raw","auto"}`) is declared —
     `0` type errors (the CompressFormat/DecompressFormat shape,
     mirroring the real production sites without touching them).
   - the reverse — the superset enum passed where the subset enum is
     declared — still `1` type error (proves this is a genuine subset
     check, not blanket enum-to-enum compatibility; this is also
     exactly the shape `cosmic/compress_test.tl:139` needs and must
     keep needing a cast).
   - two same-size enums with disjoint words — still `1` type error
     (proves an unrelated enum pair stays rejected).

3. **Correct `docs/design/casts.md`'s `### enum relation` section**
   (the "What closes it upstream" paragraph and its `hash.tl:104`
   exemplar are the source of the wrong "both rules, 11 sites" claim
   this refinement found): state that only the subset relation is a
   real gap, that tl already treats every enum as a `string` subtype,
   name the 3 sites the new rule actually targets, and swap the
   exemplar to `_fuzz/compress_fuzz_test.tl:76` (a genuine subset
   case) since `hash.tl:104` casts a `string.upper()` result — already
   plain `string`, word sets not even overlapping — into an unrelated
   enum, which was never an instance of either named rule.

Verify with `bin/cosmic --make ci` (which converges: generation 1
builds under the CURRENT `bin/cosmic.pin`, generation 2 rebuilds
`tl.lua` with the new patch entry applied and re-runs everything,
including the new `3p/tl/tl_test.tl` cases, under it).
