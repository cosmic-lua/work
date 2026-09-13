- `cosmic/check.tl`: add
  `swap_members(module: any, members: {string: any}, body: function())`
  — save `(module as {string: any})[name]` for every key
  (`-- cast: probe module surface to swap a member its declared type owns`,
  the one cast), assign the replacements, `pcall(body)`, restore every
  saved value, rethrow with `error(err, 0)` (`-- throws:` per D23,
  `check` may throw). Declare it on the `check` record and document
  it beside `is_exposed`.
- `cosmic/sandbox/init_test.tl`, `landlock_net_test.tl`,
  `landlock_scope_test.tl`: delete `with_mock_landlock`; call
  `check.swap_members(landlock, mocks, body)` at its call sites
  (`git grep -n "with_mock_landlock(" origin/main -- cosmic/sandbox/`).
- `cosmic/quicksand/box/init_test.tl:140-150`: build `mocked` with
  `require("cosmic.deep").copy(real)` (typed `Capabilities`), apply
  `overrides` through `check.swap_members`-style assignment on the
  copy — one residual cast if `overrides` must stay `{string: any}`;
  swap `quicksand.capabilities` through `check.swap_members`.
- `_build/casts_baseline.tl`: `cosmic/sandbox/init_test.tl` 4 → 1,
  `landlock_net_test.tl` 3 → 0, `landlock_scope_test.tl` 3 → 0,
  `cosmic/quicksand/box/init_test.tl` 4 → ≤ 1, `cosmic/check.tl` 3 → 4
  (`bin/cosmic --make run _build/casts.tl --baseline`); reconcile
  `docs/design/cast-sites.tsv`; `### map view of a declared value` in
  `docs/design/casts.md` keeps its four library rows.
- `bin/cosmic --make ci` ends `ci: PASS`.
