- **No scenario, `check()`, sample-count, or threshold change** —
  `DEFAULT_THRESHOLD_PCT`, `TRIAGE_K`, and every scenario stand; the
  statistics of the JUDGMENT are the subject.
- **No verdict-vocabulary or summary-format change** — strike-once
  flags reuse `"noise"`.
- **No baseline caching or stored-numbers comparison** — the
  five-release incident that banned stored baselines
  (`release.yml:137-143`'s comment) stays banned; the baseline retry
  re-measures the downloaded binary in-run.
- **`selfcheck` mode, `_perf/compare.tl`, `_perf/run.tl`,
  `_perf/baseline.tl` untouched.**
- The `json_decode_large` drift observation stays on this item's
  record as evidence for a FUTURE bisect if it flags again under the
  reproduction rule — not this slice's to chase.
