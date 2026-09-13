- No change to which bindings the tests exercise (raising coverage,
  once the floor makes a regression visible, is ordinary follow-on
  work — inherited from the parent outcome's own non-goal).
- No instrumentation outside `tool/net`, `tool/lua`, and
  `third_party/lua/cosmo` (inherited from the parent outcome).
- No change to `.github/workflows/pr.yml` — 3IvOr6Gxxn8pZGF53TUjsyrD5ML
  (ranked before this item) already makes CI build and run
  `o/cov/tool/lua/test`; once that lands, this item's new `.ok` gate is
  enforced on every PR with no further workflow change.
- No change to `tool/lua/coverage.lua` / `coverage_floor.lua` — the
  function-coverage floor stays exactly as-is; this item adds a
  parallel, differently-named mechanism, not a replacement.
