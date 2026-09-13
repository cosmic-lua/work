- **No code change anywhere, and no PR.** This is a research slice:
  its deliverable is the `## Result` section and the follow-up item.
  Nothing lands on `main`, nothing lands in whilp/cosmopolitan.
- **Do not weaken, rename, resize or remove any scenario or its
  `check()`**, `codec_base64_roundtrip_64k` first among them, and do
  not add a `--samples`/`--min-secs` override to make readings
  cheaper. The `optimize` skill's standing rule.
- **Do not commit a pin change.** The three pin edits live in scratch
  worktrees and are never pushed. `bin/cosmic.pin` is untouched —
  that is `3ISVlHT6`.
- **Do not commit any `o/perf/*.json`**, and do not commit the
  worktrees.
- **Do not `gitboard unblock` anything.** Whether the reason recorded
  on `3ISVlHT6`'s edge still binds is a judgement the reviewer makes
  from the recorded result.
- **Do not dispatch `release.yml`**, with or without `perf_gate:
  false`. It publishes outward; it is a human's call.
- **Do not touch `_perf/gate.tl`, `_perf/compare.tl` or their
  tests.** D31 just landed there (`ef963bab`); a measurement pass is
  not the place to revisit it.
- **Do not change the cosmic tree in any arm.** Only the two pin
  lines differ between worktrees.
