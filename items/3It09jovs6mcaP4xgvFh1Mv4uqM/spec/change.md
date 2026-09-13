Decide whether gitboard should opportunistically keep its own local
checkout packed, given it already knows exactly when it is safe and cheap
to check.

1. Measure how many loose objects a realistic long session actually
   accumulates locally (a day of orchestrator activity: dozens of
   `new`/`take`/`spec`/`verdict`/`done` calls) against `cosmic-lua/work`'s
   real object growth rate, to size whether this is a today problem or a
   months-from-now one.
2. If worth doing: `_work/store.tl` or `_work/publish.tl` — after a
   successful `sync` or `publish` (the two points where the checkout is
   known to be in a clean, referenced-consistent state), run `git gc
   --auto` (respects git's own threshold, so it is a no-op most of the
   time and only does real work once the checkout has actually earned it)
   rather than an unconditional `gc`.
3. Non-blocking: this must never add meaningful latency to an ordinary
   verb's fast path — measure `gc --auto`'s cost on an already-packed
   repository (expected: a single loose-object count check, no full gc)
   before landing this anywhere near `new`/`take`/`spec`.
4. Tests: a `_work/store_test.tl` (or `publish_test.tl`) case that a
   checkout with loose objects below git's threshold triggers no
   detectable extra work, and one with loose objects pushed artificially
   above it (or with the threshold lowered via `-c gc.auto=N` for the
   test) does get packed by the next `sync`/`publish`.
