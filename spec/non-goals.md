- **No new properties.** The parser slices own those; this slice runs the properties that
  exist, deeper.
- **Never auto-weaken or quarantine a failing property.** No `continue-on-error`, no
  `|| true`, no `if: always()` on the deep step itself, no per-module skip list, and no
  lowering `FUZZ_ITERS` to make a red lane green. A red deep lane stays red until the
  property or the code under it is fixed.
- No edits to `_fuzz/driver.tl` or `_fuzz/driver_test.tl`. The driver's env contract is
  settled, and `driver_test.tl` deliberately carries NO `--- env:` declaration: it sets
  and restores both variables in-process, so the ambient value is ignored there by
  design. The `_build/fuzz_test.tl` ratchet checks `*_fuzz_test.tl` only, for that reason.
- No changes to `release.yml`, and no change to any job body in `pr.yml`. A deep-fuzz
  failure must never fail or delay a release, and pr.yml's lanes keep running the fuzz
  properties at the 256 default.
- The container `image:` digest line and the `options:` line are copied byte-for-byte and
  not bumped. A digest bump is its own change (it moves the coverage floor), and
  `_build/workflows_test.tl` requires every copy to agree.
- No `issues: write`, no `contents: write`, no auto-filing or auto-commenting, and
  therefore no dependency on the board's missing `comment` verb (#1204).
- No `actions/cache` step in this lane.
- No change to the `--- env:` grammar or to the `--- reads:` grammar. `reads:` is
  single-token until #1178 lands, which is why change item 3 writes one path per line
  rather than a multi-path line that would silently no-op.
- G5's win condition — "a release ships only after a clean fuzz window" — is out of
  scope. This slice establishes the cadence; gating a release on fuzz history is a later
  slice and would need this lane's history to exist first.
