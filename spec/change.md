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
