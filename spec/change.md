- `cosmic/quicksand/proxy.tl`: in `start` (`:113`, returns
  `ProxyHandle | nil, string`), after `unix.exit(1)` at `:137` add
  `return nil, tostring(nerr)` with a comment that the line is
  unreachable and exists to narrow `srv`. Delete the comment block and
  the four casts at `:138-145`; read `listen`, `port`, `serve_forever`
  off `srv` as `serve.Server` declares them
  (`git grep -n "record Server" origin/main -- cosmic/quicksand/proxy/`
  — field closures, called without `self`, as the current code does).
- `cosmic/coverage/init.tl:173-174`: `debug.sethook(nil, "")`, one
  comment: nil hook clears the hook.
- `cosmic/check_assertions_test.tl:341`: the wrapper form above.
- `cosmic/quicksand/init.tl:73`: keep the cast; reason becomes
  `-- cast: runtime capability probe: fn is any, an arbitrary binding`;
  in `docs/design/cast-sites.tsv` change that row's class to
  `runtime capability probe` by hand (reconcile carries class by
  path+line, it never rewrites one), then run
  `bin/cosmic --make run _build/cast_sites.tl --reconcile` and confirm
  it reproduces the file.
- `_build/casts_baseline.tl`: `cosmic/quicksand/proxy.tl` 5 → 1,
  `cosmic/coverage/init.tl` 5 → 4, `cosmic/check_assertions_test.tl`
  3 → 2 (`bin/cosmic --make run _build/casts.tl --baseline`).
- `docs/design/casts.md` `### function shape`: rewrite the verdict to
  name the residual four as the generator's dropped success overload
  (see `gentype-overloads`); `### record union after guard` drops the
  proxy exemplar if it cites `:141`
  (`git grep -n "proxy.tl:14" origin/main -- docs/design/casts.md`).
- `bin/cosmic --make ci` ends `ci: PASS`.
