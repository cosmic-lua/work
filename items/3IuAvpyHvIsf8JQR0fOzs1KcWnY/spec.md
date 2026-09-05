## Evidence

`1Lhz_38Wt` ("casts: dynamic-name-lookup's 8th site (package.searchers
decline shape) needs a tl_patch entry or a re-scoped 7-of-8 close") was
re-scoped by refinement to land ONLY a new
`3p/tl/tl_patch/declining_searcher.tl` patch entry (teaching tl's
builtin `package.searchers` type that a declining searcher may return a
bare `string`, not a loader) plus the `.cosmic-coverage` baseline row
the new source needs. It deliberately does NOT remove
`cosmic/searcher_test.tl:57-58`'s `-- cast: package.searchers entries
are untyped` cast.

The reason: `_build/coldbuild_test.tl` type-checks the WHOLE tree in
generation 1 using the PINNED release's own embedded `tl` checker
(`o/bootstrap/cosmic`, invoked with `--include-dir .` so it resolves
MODULES from the tree while the CHECKER itself stays the pin), not the
freshly-patched `o/3p/tl/tl.lua`. The pinned release
(`bin/cosmic.pin`, currently `2026-09-04-5d5dc3a`) predates the new
patch, so its `package.searchers` type has no `| string` arm; removing
the cast in the same PR as the patch makes gen1 fail at
`cosmic/searcher_test.tl:58` with:

    cosmic/searcher_test.tl:58:19: warning: why (of type function(? string, ? <any type>): <any type>) can never be a string
    cosmic/searcher_test.tl:58:19: error: why (of type function(? string, ? <any type>): <any type>) can never be a string
    cosmic/searcher_test.tl:58:29: error: cannot resolve a type for why here

This is the exact staging rule `AGENTS.md`'s Build System section
already names: "a source that needs the tree's own checker (a new
narrowing rule, a new patch entry) passes the converged `--make ci`
and fails only a cold build... Such a change stages behind a release
and pin bump: land the checker first, bump `bin/cosmic.pin` to a
release carrying it, then land the code that needs it."

This item is that pin-bump half's consequence, exactly as `vBk9_UxhS`
("cosmic: bump bin/cosmic.pin to close socket.tl:437's setsockopt
timeval cast") is `keP3_sWNy`'s: a `cosmic-lua/cosmopolitan`-side
annotation landed there without its `cosmic-lua/cosmic`-side cast
removal, filed as a sibling `blocked_by` the annotation item, ready
only once a release exists carrying it. Here both halves are
`cosmic-lua/cosmic`-internal (the patch file and the pin that must
carry it are the SAME repo's own pin to itself), but the shape is
identical: land the checker/patch, cut a release, bump the pin, THEN
remove the cast that needs the new union arm.

Once `1Lhz_38Wt` merges, the patch is in the tree's `main` branch but
NOT yet in any released `cosmos`-equivalent artifact this repo's own
`bin/cosmic.pin` points at — `bin/cosmic.pin` names a `cosmic` release
built FROM this tree, and gen1 of every build (including the release
build itself, and every downstream repro/smoke lane) uses whatever
`bin/cosmic.pin` currently names. `release.yml` cuts a release daily
off `main`, so the patch will be in some release the day after
`1Lhz_38Wt` merges (or sooner via a manual `workflow_dispatch`), but
the FIX only reaches gen1's checker once `bin/cosmic.pin` is bumped to
name that release — the daily cut alone does not move the pin.

## Change

Ready when: `1Lhz_38Wt` is `done` (`gitboard show 1Lhz_38Wt` reports
`resolution: completed` and a merge commit sha), AND a `cosmic` release
exists whose tagged commit descends from that merge commit — verify
with `git merge-base --is-ancestor <1Lhz_38Wt-merge-sha>
<release-tag-short-sha>` (exit 0 = descends; the release tag is
`YYYY-MM-DD-<short-sha>`, matching `bin/cosmic.pin`'s current `url`
line shape), AND `bin/cosmic.pin` is bumped to (or already at) that
release's url + sha256. Until all three hold this item is not
resolvable — re-offered as-is rather than answered with a guess at
which release will carry the fix.

Once ready:

- `bin/cosmic.pin`: bump to the qualifying release (url + sha256, the
  normal pin-bump shape) if not already there when this is picked up.
- `cosmic/searcher_test.tl:57-58`: delete the `-- cast:` comment line
  and change `pcall((s as function(string): any), missing)` to
  `pcall(s, missing)`.
- `_build/casts_baseline.tl`: run `bin/cosmic --make run _build/casts.tl
  --baseline` and commit — this drops the now-zero
  `["cosmic/searcher_test.tl"] = 1` entry.
- `docs/design/cast-sites.tsv`: run `bin/cosmic --make run
  _build/cast_sites.tl --reconcile` — this drops the
  `cosmic/searcher_test.tl	58	dynamic name lookup` row. Whether the
  class's heading and remaining rows survive depends on whether
  `q0zL_uDdq`'s 7 `_make/init.tl` sites have landed by then: if they
  have, the whole `dynamic name lookup` section reaches zero rows and
  the section-deletion step in `_build/cast_sites_test.tl` applies; if
  they have not, 7 `_make/init.tl` rows remain and no section-deletion
  step applies. Check `docs/design/cast-sites.tsv` at pick-up time to
  see which case holds.
- `docs/design/casts.md`: in the `### dynamic name lookup` section,
  replace "The searcher slot wants a declared record and nothing
  more." with "The searcher slot's decline (a bare string, not a
  loader) has no arm in tl's builtin `package.searchers` type; a
  carried `3p/tl/tl_patch/` entry teaches it the union, closing the
  last one."
- `bin/cosmic --make ci` ends `ci: PASS`.

## Non-goals

The 7 `_make/init.tl` dynamic-name-lookup sites and `policy.must_verb`
are `q0zL_uDdq`'s scope — untouched here regardless of landing order
between the two items (see the tsv step above for how their landing
order changes what `--reconcile` produces).

Landing `3p/tl/tl_patch/declining_searcher.tl` itself and its
`.cosmic-coverage` baseline row are `1Lhz_38Wt`'s scope, already
landed by the time this item is ready — not repeated here.
