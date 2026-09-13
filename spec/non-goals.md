- **No code change on `main`, no commit or push in whilp/cosmopolitan,
  and no PR in either repo.** Arm C's `BUILD.mk` edit lives in a scratch
  checkout and is recorded as a diff in `## Result`, never landed —
  however obvious the answer looks once the numbers are in. Landing it
  is the follow-up's, and (7) says why.
- **Do not build or measure in default mode.** Both the `-DFTRACE`
  padding and the suppressed inlining make it a different program;
  `## Evidence` has the line numbers. Every arm is `m=rel`.
- **Do not mix a local build against a released one.** All three arms
  are local `m=rel` builds from one checkout with one toolchain, per
  `skills/optimize/cosmopolitan.md` step 2.
- **Do not change the verdict rule, the reading count, or the sample
  settings mid-slice**, and do not discard a reading as an outlier
  beyond the trim in (6). If B and C both read NOT SEPARATED, that is
  the third row of (7) and it is a result, not a failed run to repeat
  on a quieter host.
- **Do not re-measure the released arms** or re-run `3ITOUv0w`'s
  bisect. Its attribution is accepted and is this slice's premise.
- **Do not move a binding contract.** Nothing here edits
  `tool/net/definitions.lua`, a return shape, an error value or a
  constant — the freeze in both repos' AGENTS.md — and arm C is a link
  ORDER change, which touches none of them.
- **Do not weaken, rename, resize or remove any scenario or its
  `check()`**, `codec_base64_roundtrip_64k` first among them, and do
  not pass `--samples`/`--min-secs` overrides. The `optimize` skill's
  standing rule.
- **Do not commit a pin change.** `3p/cosmos/cosmos_pin.tl` is not
  edited in any worktree, and `bin/cosmic.pin` is `3ISVlHT6`'s.
- **Do not commit any `o/perf/*.json`**, and do not commit the
  worktrees.
- **Do not `gitboard unblock` anything**, do not touch `3ISVlHT6`, and
  do not end `3ITVR6Ku` — it stays open as this slice's parent until
  its fix lands.
- **Do not dispatch `release.yml`** in either repo, with or without
  `perf_gate: false`. It publishes outward; it is a human's call.
- **Do not fix `skills/optimize/cosmopolitan.md`.** The mode error is
  captured as `3ITbbvg7` and is that item's to correct; this spec
  states the right fact and needs nothing from the doc.
