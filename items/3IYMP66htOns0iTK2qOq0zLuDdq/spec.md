## Evidence

Measured 2026-09-03 against `origin/main` (`96afd807`), checks run
under the pinned release (`o/bootstrap/cosmic`, the `bin/cosmic.pin`
binary).

The class is 8 rows: `_make/init.tl` 7, `cosmic/searcher_test.tl` 1
(`git show origin/main:docs/design/cast-sites.tsv | awk -F'\t' '$3=="dynamic name lookup"'`).
The earlier spec's premise — a "loosely typed row" from the registry —
is false. `by_name` is already typed nilable:

    git show origin/main:_make/init.tl | sed -n '71p;326p'
    local by_name: function(name: string): Verb | nil
    by_name = function(name: string): Verb | nil

    git show origin/main:_make/init.tl | grep -n "as Verb"
    143:  local v = by_name("build") as Verb -- cast: the registry defines it
    184:    local b = by_name("build") as Verb -- cast: the registry defines it
    246:      return stage.run_graph(by_name("fmt") as Verb, proj, paths, cosmic)
    251:      return run_against_stage(by_name("test") as Verb, proj, paths, cosmic)
    283:      return run_against_stage(by_name("example") as Verb, proj, paths, cosmic)
    291:      return run_against_stage(by_name("benchmark") as Verb, proj, paths, cosmic)
    300:      local v = by_name("coverage") as Verb -- cast: the registry defines it

So every one is `Verb | nil` → `Verb`: the proved-value-narrowing
shape #1646 closed elsewhere, not a dynamic lookup. The carried patch
narrows it without a cast — probe (`--check types`, pinned binary):

    local a = by_name("x"); assert(a, "registry defines it"); use(a)
    local b = by_name("x"); if not b then error("no") end; use(b)
    → Type check passed

The two nil-consuming callers stay nilable: `_make/init.tl:428`
(`local v = by_name(name)`, argv dispatch) and `_make/policy.tl:316`
(`if not (v is Verb) then` … "ci names a verb that does not exist").

Headroom: `git show origin/main:_make/init.tl | wc -l` → 498 (cap 500),
so no helper fits there; `_make/policy.tl` → 376, and `init.tl` already
requires it (`init.tl:30`) and hands it `by_name` (`init.tl:296`).

**Re-scoped 2026-09-05: this item is now 7 of the 8 sites, not 8.**
The eighth site, `cosmic/searcher_test.tl:57-58`, does not close as a
plain cast removal — `1Lhz_38Wt` ("casts: dynamic-name-lookup's 8th
site (package.searchers decline shape) needs a tl_patch entry or a
re-scoped 7-of-8 close") worked that site in full and found it needs a
`3p/tl/tl_patch/` builtin-type patch that only reaches generation 1's
checker once a release carrying it is cut AND `bin/cosmic.pin` is
bumped to it (`_build/coldbuild_test.tl`'s gen1 rule, `AGENTS.md`'s
Build System section). `1Lhz_38Wt` landed the patch alone (merged,
`resolution: completed`); the searcher_test.tl cast removal itself,
plus the class's final tsv/casts.md reconcile, is `zs1K_cWnY`
("casts: land searcher_test.tl's cast removal once the
declining-searcher patch is pinned"), which is `blocked_by`
`1Lhz_38Wt` and not yet ready (needs a release + pin bump first). This
item's own scope was always the 7 `_make/init.tl` sites — the `##
Change` below is corrected to stop touching
`cosmic/searcher_test.tl` and to stop trying to zero the whole class,
which `zs1K_cWnY` now owns.

Re-verified against `origin/main` at `22e5233` (post-`1Lhz_38Wt`
merge): `wc -l _make/init.tl _make/policy.tl` → 498 / 375 (headroom
unchanged), the same 7 `as Verb` sites at the same lines (`grep -n "as
Verb" _make/init.tl`), and `cast-sites.tsv`'s `dynamic name lookup`
class still 8 rows with `cosmic/searcher_test.tl	58` still present
(`awk -F'\t' '$3=="dynamic name lookup"' docs/design/cast-sites.tsv`)
— untouched by `1Lhz_38Wt`, exactly as its own spec recorded.

**A first build attempt (2026-09-05, uncommitted-to-board) implemented
the `## Change` below exactly and hit a real gap this refinement
missed**: `bin/cosmic --make ci` failed at the `lint` stage —

    docs/design/casts.md:275:1: doc-citation: docs/design/casts.md:275: the quoted line is not _make/init.tl:143 —
    document has `local v = by_name("build") as Verb -- cast: the registry defines it`,
    source has `local v = policy.must_verb(by_name, "build")`.

`docs/design/casts.md`'s `### dynamic name lookup` section
(`docs/design/casts.md:264-278`) fence-quotes `_make/init.tl:143` as
its illustrative citation (`_cli/citations.tl`'s doc-citation check,
which compares a fenced `-- <path>:<line>` block against the tree
verbatim). This item's own Change rewrites that exact line, so the
citation goes stale as a direct, unavoidable consequence of doing the
`_make/init.tl` replacement — confirmed the check passes clean on the
pre-change tree (`git stash`, `bin/cosmic --check lint
docs/design/casts.md` → PASS) and fails only once the 7-site
replacement lands.

This is a citation-accuracy gap, not a reopening of the Non-goals
wall below: the wall reserves the section's EXPLANATORY prose (the
"What closes it here" paragraph, including its now-stale "wants a
declared record" sentence about the searcher slot — `1Lhz_38Wt`
already recorded that this sentence stays wrong until `zs1K_cWnY`
rewrites it) for `zs1K_cWnY`. The fenced CODE CITATION right above
that paragraph is a different thing: a mechanically-checked quote of
one still-live site in the class, and after this item lands the only
still-live site is `cosmic/searcher_test.tl:58`
(`sed -n '58p' cosmic/searcher_test.tl` →
`    local ok, why = pcall((s as function(string): any), missing)`,
untouched by this item). Repointing the citation to that line keeps
the section's fenced example accurate without rewriting a word of the
explanatory prose the wall protects.

## Change

- `_make/policy.tl`: add and export on `PolicyModule`
  `must_verb(by_name: function(string): Verb | nil, name: string): Verb`:
  `local v = by_name(name)`, then
  `assert(v, "make: no verb " .. name) -- assert: the registry is literal data in _make/init.tl and every name passed here is a row it defines`
  (D30's infallible-by-type contract boundary; the trailing `-- assert:`
  satisfies `assert-justify`), `return v`.
- `_make/init.tl`: at the seven lines above replace
  `by_name("<x>") as Verb -- cast: …` with `policy.must_verb(by_name, "<x>")`.
  Net line count must stay ≤ 500 (`wc -l`); the replacement removes no
  lines and adds none.
- `_build/casts_baseline.tl`: `_make/init.tl` row 7 → gone; run
  `bin/cosmic --make run _build/casts.tl --baseline` and commit.
- `docs/design/cast-sites.tsv`: run `bin/cosmic --make run
  _build/cast_sites.tl --reconcile`. This drops only the 7
  `_make/init.tl` rows; the `cosmic/searcher_test.tl	58` row survives
  (it is `zs1K_cWnY`'s, untouched here), so the `dynamic name lookup`
  class ends this item with exactly 1 row, and
  `_build/cast_sites_test.tl`'s every-heading-has-a-row check still
  passes without a section deletion. Do not delete
  `docs/design/casts.md`'s `### dynamic name lookup` section here —
  it still has a live row.
- `docs/design/casts.md:274-275`: repoint ONLY the fenced citation's
  header and quoted line — nothing else in the section — from

  ```text
  -- _make/init.tl:143
    local v = by_name("build") as Verb -- cast: the registry defines it
  ```

  to

  ```text
  -- cosmic/searcher_test.tl:58
    local ok, why = pcall((s as function(string): any), missing)
  ```

  Leave every other line of the section (the class description above
  the fence and the entire "What closes it here" paragraph below it,
  including its stale "wants a declared record" sentence) byte-for-byte
  unchanged — that paragraph is `zs1K_cWnY`'s to rewrite, not this
  item's.
- `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

The `E*`/`SIG*` constant lookups (`binding constant by name`, 5 rows)
are item `3ISJHfNY` — untouched here.

`cosmic/searcher_test.tl:57-58`'s cast itself, the `dynamic name
lookup` class's final row, and `docs/design/casts.md`'s EXPLANATORY
prose for the class (the "What closes it here" paragraph) are
`zs1K_cWnY`'s scope regardless of landing order between the two items
— untouched here (mirrors `zs1K_cWnY`'s own Non-goals, which names
this item's 7 sites as its own untouched half). The one exception,
scoped narrowly above, is repointing the section's fenced citation
line so it keeps quoting a real, still-live site — a mechanical
consequence of this item's own edit to `_make/init.tl:143`, not a
rewrite of the prose the wall protects.
