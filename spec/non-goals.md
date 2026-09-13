- Do not touch `rand.bytes`, `rand.int`, `rand.float`, `rand.choice`,
  `rand.shuffle`, or `rand.token` — signatures, bodies, and doc
  comments stay byte-identical (verified in Acceptance). No
  module-level seed affecting them.
- Do not touch `cosmo.Rand64` or `cosmo.GetRandomBytes` bindings.
- Do not modify `_fuzz/driver.tl`'s `Options`/`run` contract or wire it
  to use `rand.insecure_source` — that is a separate, blocked-on-this
  follow-on slice.
- Do not modify `cosmic/fetch/init.tl`'s `backoff` — it stays on
  `math.random()` for now; migrating it is part of the same follow-on
  wiring slice, not this one.
- Do not give `Source` a `next()`/`bytes()`/`choice()`/`shuffle()`/
  `token()` method — only `int()` and `float()`, the two primitives the
  named callers (fetch's jitter, fuzz-style input generation) need.
- Do not claim cross-release byte-stability for `insecure_source`'s
  output, and do not add a golden-value/pinned-byte test — the
  Acceptance test proves same-process reproducibility only.
- Do not open a new decision record (no `d28-*.md`) — the amendment
  lands as a paragraph inside D22, per the plan above.
