- **Rewriting `.cosmic-coverage` itself** (running `--baseline` and
  committing the result) is explicitly OUT of this slice. The fix
  changes what `parse` several files' `/zip`-attributed `.cov` entries
  resolve to, and `_tool/coverage/baseline.tl`'s own doc comment warns
  that "several rows were set by hand to the number the strictest
  environment produces... a rewrite from whatever machine is at hand
  would raise them to what THIS machine reaches" — a floor regeneration
  needs its own reviewed change with a diff a human reads (per D27 and
  `baseline.tl`'s `lowered()`), not a side effect bundled into a bug
  fix. Note for that follow-up: the per-file tolerance formula
  (`file_tolerance_pp`, `max(1.0, 200/total)`) is large enough for
  4-line files that `cosmic/fs/octal.tl`'s true 2/4 does **not** trip
  the ratchet against the committed (wrong) 2/2 today — `have=50.0` is
  not `< want(100.0) - slack(50.0)`. So this fix will not turn CI red;
  the stale `2 2` row can be corrected in its own follow-up at leisure.
- **Every other `.cosmic-coverage` row.** This investigation confirms
  the mechanism and one instance (`cosmic/fs/octal.tl`); it does not
  attempt to audit which, if any, other rows are similarly deflated by
  the same first-wins-the-race bug. That audit is a reasonable
  follow-up but is not this slice.
- **Issue #1205 (bench coverage measurement disagreeing between CI and
  local)** is explicitly out of scope, and I believe it is a **separate
  root cause**, not the same bug: #1205 is described as *covered*-line
  variance tied to a timing-bounded smoke pass (a flaky hit/no-hit on
  timing-sensitive branches), whereas this bug is a *total*-line
  (denominator) collapse from a static-analysis failure on a
  non-timing-dependent file, order-dependent on `.cov` merge order, not
  on timing. Nothing in this investigation found a shared mechanism —
  do not fold #1205 into this fix or close it as a duplicate.
- **`cosmic/fs/octal.tl`'s module-top-level lines (26, 30) never
  registering as "hit."** Independent of this bug: even with the fix
  applied and static analysis succeeding, lines 26 (`local M = {...}`)
  and 30 (`return M`) show up in **every** `.cov` file's hit table for
  this module as absent — the module's top-level code appears to run
  (via `require`) before whatever attaches the coverage line hook in
  every process observed. That may be a real, separate coverage-fidelity
  gap (module-load-time lines undercounted repo-wide) worth its own
  investigation, but fixing or even fully diagnosing it is not this
  slice — this slice only restores the TOTAL to what static analysis
  actually says.
- **The `o/<path>.lua` staged-artifact branch of `normalize()`** (lines
  118-133, the non-`/zip/` compiled-artifact mapping) is not touched —
  it already returns a readable staged Lua **text** file as `parse`,
  confirmed to preserve `tl.generate`'s line-number correspondence with
  the original source, and has its own passing test
  (`test_normalize_maps_compiled_artifact_to_source`).
