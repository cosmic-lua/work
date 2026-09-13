- **Do not merge, reopen, or re-land whilp/cosmopolitan#263.** Closed, draft,
  unmerged, and its own author's conclusion is that it should not ship. This
  slice's negative result strengthens that, not weakens it.
- **No change to any file in either repo.** No cosmos pin bump, no edit under
  `_perf/`, `skills/optimize/`, or `cosmic/tar*`. The scenario and its `check()`
  are frozen: never weaken a scenario to make numbers move.
- **Do not commit `o/perf/*.json`** or the downloaded A binary.
- **Do not judge this from a full-suite compare** — the suite's ~20 preceding
  scenarios leave a thermal/cache wake worth up to 40% (`measurement.md:47`).
- **Do not extend the run to the other 42 scenarios** — 3IHCIZWU settled those.
