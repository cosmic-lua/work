- **No behaviour change to coverage instrumentation.** Wrappers still
  arm coroutines and flush on `os.exit`; the new impossible-miss guard
  leaves the stdlib entirely unpatched rather than half-patched or
  crashed. `--make coverage` must end `coverage: PASS` (refinement
  measured it: `PASS (240 files)`).
- **No `rand.choice` behaviour change** — same element, same nil on
  empty; the generic is inference-only and all callers live in the
  test file.
- **Do not touch `cosmic/_teal_engine.tl`, `cmd/cosmic/main.tl`,
  `cosmic/_seal_coverage.tl`** — sibling `3IQRDRwW` (PR #1396, in
  check); the two slices share only `_build/casts_baseline.tl`, whose
  conflict is the mechanical regen. Land whichever merges second via
  rebase + regen.
- **A reason rewrite is not a count trick**: the one surviving new
  cast names what is genuinely unnarrowable (pack-n erasure), probed.
- **No gate weakened**; the baseline moves only through the printed
  regen command.
