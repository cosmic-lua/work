- **No code change anywhere, and no PR.** This is a research slice: its
  deliverable is the `## Result` section and the one follow-up item.
  Nothing lands on `main`, nothing lands in whilp/cosmopolitan — a fix
  is the follow-up's, not this slice's, however obvious the answer
  looks once the commit is named.
- **Do not re-measure `bf92718a1` or `8e071ec98`.** They are eliminated
  by byte-identical runtimes, which is a proof and not a sample; adding
  them back spends readings on a settled question.
- **Do not change the verdict rule, the reading count, or the sample
  settings mid-slice**, and do not discard a reading as an outlier
  beyond the trim (6) specifies. If the rule again fails to separate,
  (7) is what to do.
- **Do not build whilp/cosmopolitan locally for the arms.** The
  released `cosmos.zip` binaries are the instrument; a default-mode
  single-arch local build is a different build configuration and cannot
  be trusted against a layout hypothesis.
- **Do not weaken, rename, resize or remove any scenario or its
  `check()`**, `codec_base64_roundtrip_64k` first among them, and do
  not pass `--samples`/`--min-secs` overrides. The `optimize` skill's
  standing rule.
- **Do not commit a pin change.** Every pin edit lives in a scratch
  worktree and is never committed or pushed. `3p/cosmos/cosmos_pin.tl`
  on `main` is untouched, and `bin/cosmic.pin` is `3ISVlHT6`'s.
- **Do not commit any `o/perf/*.json`**, and do not commit the
  worktrees.
- **Do not change the cosmic tree in any arm.** Only the two pin lines
  differ between worktrees; `5ef13f40` is the tree for all of them.
- **Do not `gitboard unblock` anything**, and do not touch `3ISVlHT6`.
  Whether its edges still bind is judged from the recorded result, by
  the reviewer.
- **Do not dispatch `release.yml`** in either repo, with or without
  `perf_gate: false`. It publishes outward; it is a human's call.
- **Do not touch `_perf/gate.tl`, `_perf/compare.tl`, `_perf/run.tl`,
  `_perf/harness.tl` or their tests.**
  [D31](../../docs/decisions/d31-gate-noise-from-every-control-pair.md)
  landed there in `ef963bab`; a measurement pass is not the place to
  revisit it.
