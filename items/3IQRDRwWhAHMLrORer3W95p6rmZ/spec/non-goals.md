- **No behaviour change.** A script that throws still exits 1 with the
  trimmed traceback on stderr (`run.trim_traceback` remains the direct
  xpcall handler — do not wrap it, which would add a frame to the
  traceback); `cosmic --version`, `-c`, and the REPL paths are
  untouched. The coverage seal still no-ops when `cosmic.coverage` was
  never loaded and still respects `is_kept_on_restrict()`.
- **Do not hoist `_teal_engine.tl`'s `require("tl")` to file scope**
  to enable the alias — the lazy load is deliberate, and restructuring
  the module's type exports is not this slice.
- **`cosmic/coverage/init.tl` is not this slice's** — its casts are
  `3IQREPC5`'s.
- **Do not make `_seal_coverage.tl` require `cosmic.coverage`.** The
  `package.loaded` read is the point of the module.
- **No new public module and no new export.**
  `_build/public_surface_baseline.tl` must not move.
- **Do not touch the other `from any` casts** — 26 lines carry that
  reason today (command in Evidence); only the six above are this
  slice's, and one of them survives with its truer reason.
