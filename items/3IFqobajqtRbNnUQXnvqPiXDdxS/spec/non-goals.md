- **Do not change `cosmo.cov`, `definitions.lua`, or anything in
  whilp/cosmopolitan.** That contract is frozen here and lands as
  `3IFqha5Y`; this slice consumes it.
- No change to the failure message format (`budget=%d exceeded`), to
  `Options`' field names, or to `DEFAULT_BUDGET` / `DEFAULT_TIMEOUT_MS`
  values — `driver_test.tl` and the `*_fuzz_test.tl` properties read
  them.
- Do not remove the wall-clock `timeout_ms` backstop or its doc: a hang
  inside a single C call is still outside every instruction hook's
  reach, which is what that backstop is for.
- No change to `cosmic/coverage/init.tl` — the collector's Lua wrapper
  is not in this slice, and the driver reaches `cosmo.cov` directly the
  way that module already documents.
- No new `cosmic.*` public module or wrapper for `cov.budget`; `_fuzz`
  is internal and reaches the binding directly, as
  `cosmic/coverage/init.tl` does.
- Do not touch `.github/workflows/fuzz.yml`.
