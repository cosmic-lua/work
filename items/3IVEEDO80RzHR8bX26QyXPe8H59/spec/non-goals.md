- **No new field in the results file.** `meta.timestamp` already exists
  (Evidence 1); nothing in `_perf/run.tl` changes. In particular, do
  NOT add a start-of-run stamp, a session id, a hostname, or a run
  uuid — the wall-clock stamp already on disk is the whole subject.
- **`_perf/run.tl` and `_perf/gate.tl` are not touched at all.** Both
  already reach the header through `compare.format` (Evidence 9).
  `_perf/gate.tl` is also at 478 of 500 (Evidence 10) — nothing may be
  added to it here.
- **No gap becomes a decision.** The `measured:` line is informational
  and may never refuse, warn, change an exit code, raise a bar, or feed
  `diff`/`triage`/`triage_many`/`loudest_control`.
  `DEFAULT_THRESHOLD_PCT` stays `10.0` and `TRIAGE_K` stays `2.0`
  (`_perf/compare.tl:19,27`). 3IU0GxoA's "What this does NOT license"
  binds: the 20-33% cross-session spread is NOT a noise budget, and the
  release lane measures baseline and candidate in the SAME job on the
  SAME runner.
- **`identity_refusal` is untouched** — its rule, its wording, and
  where `gate.tl` calls it. This item makes a fact VISIBLE; what the
  gate REFUSES on does not move. (#1486 is separately changing that
  function; do not merge, revert, or anticipate its change here.)
- **No per-row column and no second level field.** `format_delta`
  already prints both absolute levels (Evidence 7) and its format
  string is not edited.
- **No `format_identity` rewrite.** The `binaries:` line landed with
  #1485 and is consumed here as-is; this item adds a line beneath it
  and changes none of its text.
- **The exported `compare` record does not widen.** `format_gap` and
  `format_measured` stay file-local.
- **No history store, no derived per-scenario floor** — that is
  3IVDirCO's subject, and it is not opened here.
- No scenario, `check()`, or bench-module change; no codec row weakened
  or removed from any compare.
- Code comments carry no item ids, PR numbers, or dates
  (`skills/docs-style`).
