1. Pick the first release whose tag commit contains `8758f80c` (which
   contains `96afd807` and `f156e879`): `gh release list --limit 5`,
   then for the candidate tag
   `git merge-base --is-ancestor 8758f80c <tag-sha>` (tag is
   `YYYY-MM-DD-<sha7>`, `release.yml:70-75`); a prerelease is fine —
   the current pin is one.
2. `bin/cosmic.pin`: set `url` to
   `https://github.com/cosmic-lua/cosmic/releases/download/<tag>/cosmic-lua`
   and `sha256` to `sha256sum` of that asset, downloaded once with
   `curl -fsSL`. Nothing else in the file.
3. Prove the bump from cold:
   `rm -rf o && bin/cosmic --make fetch && bin/cosmic --make build`,
   then the probe above against the new `o/bootstrap/cosmic` prints
   `present`, and `o/bootstrap/cosmic -e '…' | grep -A3 "record Env"`
   shows `report_types` and `loaded`, and
   `unzip -l o/bootstrap/cosmic | grep _make/seed.lua` prints one row
   (the seed pass is now what generation 1 runs).
4. `bin/cosmic --make ci` ends `ci: PASS` (`_build/coldbuild_test.tl`
   re-checks the tree under the new pin; `_make/fixpoint_test.tl`
   under `COSMIC_FIXPOINT=1` is the two-build proof).
