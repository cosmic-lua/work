- the CLI's shape does not change: `compare` keeps three positional
  paths and `selfcheck` two, so
  `.github/workflows/release.yml:163` and every documented invocation
  keep working untouched. Do not edit the workflow.
- `SELFB.json` stays an output. It is the A/A control's destination and
  always was; the fix is to SAY so, not to move it.
- no change to `_perf/compare.tl`, `_perf/run.tl`, or the
  `perf-compare: PASS`/`FAIL` verdict line format — the release
  workflow greps it.
- no new temp-directory machinery, and no deleting the retry file: a
  failed gate's evidence is worth keeping.
- `AGENTS.md`'s Performance section lists the two commands without
  argument semantics; leave it — the usage line and the skill are where
  that belongs.
