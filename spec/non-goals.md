- Do NOT change the public `distance()` function's signature, body, or
  observable behavior. Its callers (`_cli/require_hints.tl:114-115`
  and `cosmic/fuzzy_test.tl`) must stay green unchanged. `distance()`
  is not switched to the shared arrays or the early abort — those live
  only in the internal helper for `find_similar`.
- Do NOT change `find_similar`'s observable behavior: same match set,
  same per-match `distance`, same sort (distance then value), same
  dedup-on-lowercase, same `limit` semantics. Its callers
  (`cosmic/doc/show.tl:408,438`) must see identical results.
- Do NOT implement the Ukkonen / diagonal-band variant — that is a
  separate, larger algorithmic change and is out of scope for this
  slice.
- Do NOT weaken, rename, or edit the `fuzzy_find_similar` scenario or
  its `check()` in `_perf/bench/fuzzy_bench.tl`.
- The helper must not yield (no coroutine boundary): the shared arrays
  are safe only under the single-threaded VM assumption.
