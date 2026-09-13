- **No code change on `main`, no commit or push in whilp/cosmopolitan,
  and no PR in either repo.** The script lives at `/tmp/b64split.lua`
  and is never added to the tree; whether a per-call split belongs in
  `_perf` at all is a separate question this slice does not answer.
- **Do not build or measure in default mode.** The `-DFTRACE` padding
  (`build/config.mk:492-495,522`) and the suppressed inlining make it a
  different program from the released `m=rel` one. Both arms are
  `m=rel`, as `3ITbccMu`'s `## Evidence` establishes.
- **Do not measure arm C or rebuild it.** `3ITbccMu` proved it
  layout-identical to arm B; re-measuring it spends readings on a
  settled question.
- **Do not use a released `cosmos.zip` binary as an arm**, and do not
  mix a local build against a released one.
- **Do not build cosmic at all.** This slice measures the raw arm
  `lua` binaries; no cosmic worktree, no `--make fetch`, no
  `--make build`, no `o/3p/cosmos/lua` swap. The end-to-end number is
  `3ITbccMu`'s and is not re-measured here.
- **Do not change the script, the reading count, the sample settings
  or the rule mid-slice**, and do not discard a reading as an outlier
  beyond the trim in (4). Every row of (5) is a result, including the
  two that say the instrument missed.
- **Do not move a binding contract.** Nothing here edits
  `tool/net/definitions.lua`, a return shape, an error value or a
  constant — the freeze in both repos' AGENTS.md.
- **Do not weaken, rename, resize or remove any scenario or its
  `check()`**, `codec_base64_roundtrip_64k` first among them.
- **Do not commit a pin change.** `3p/cosmos/cosmos_pin.tl` is not
  edited anywhere, and `bin/cosmic.pin` is `3ISVlHT6`'s.
- **Do not `gitboard unblock` anything**, do not touch `3ISVlHT6`, do
  not end `3ITVR6Ku`, and do not give `3ITbccMu` a verdict.
- **Do not dispatch `release.yml`** in either repo, with or without
  `perf_gate: false`. It publishes outward; it is a human's call.
- **Do not fix `skills/optimize/cosmopolitan.md`.** Its build-mode
  error is `3ITbbvg7`'s to correct.
