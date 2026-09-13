- **Defect 3 (race-free `fs.optional`)** is not touched: this slice
  does not change `present_only`/`effective_fs` in
  `cosmic/sandbox/init.tl`, does not add `IgnoreIfMissing`-style
  per-rule ENOENT tolerance to `landlock.tl`'s `restrict()`, and does
  not touch `cosmic/sandbox/plan.tl`.
- **Defect 4 (honest per-section enforcement report / `strict`
  option)** is not touched: `Availability`'s shape in
  `cosmic/sandbox/init.tl`, `apply()`'s return contract, and the
  `best_effort` truthy-but-nothing-enforced footgun are all unchanged.
- **The ABI drift alarm** (a test that fails when the running kernel's
  Landlock ABI exceeds the highest one `abi_mask` models) is not built
  here — it is a separate item that depends on this one landing first
  (see Enablement).
- **Defect 2 (REFER granted with `rw`)** — already fixed in the tree
  (`WRITE` includes `REFER`, `abi_mask` strips it below ABI 2, and
  `test_rw_grant_allows_rename_within_its_tree` in
  `cosmic/sandbox/landlock_test.tl` exercises it); nothing to do here
  and this slice does not touch that code path.
- No change to `landlock.tl`'s `abi()`/`available()`/`restrict()`
  contracts, return values, or caching mechanism — it is the retained
  canonical source both callers delegate to, and stays exactly as it
  is today.
- No change to the WITH-ARGUMENTS `landlock_create_ruleset(handled, 0)`
  call in `landlock.tl` (the real ruleset creation) — only the two
  duplicate bare-probe call sites move.
- No change to `cosmic.quicksand.types.Capabilities`'s field shape —
  `capabilities().landlock` stays a plain boolean with the same
  semantics.
- No change to `pledge.available()` or its probing — the epic's "three
  uncoordinated Landlock probes" note names exactly `landlock.abi`,
  `unveil.available`, and `quicksand.probe_landlock`; pledge uses a
  different mechanism (`probe(unix.pledge)`) and is out of scope.
- Not the C-layer ceiling work (Phase 2, whilp/cosmopolitan) or the
  `net` section (Phase 3) — epic-level non-goals, unaffected either
  way by this slice.
- Not a portable-default-deny change and not a rewrite of quicksand's
  netns/proxy — epic-level non-goals.
