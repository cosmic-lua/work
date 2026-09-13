Edit `cosmic/fuzzy.tl` only (measured `wc -l cosmic/fuzzy.tl` = 134,
so ~366 lines of headroom under the 500-line cap; the change adds
~30 lines).

1. Add two module-level scratch arrays shared across calls, declared
   once near the top of the module:
   `local dp_prev: {integer} = {}` and `local dp_curr: {integer} = {}`.
   They replace the two fresh `{}` tables allocated per call at
   `cosmic/fuzzy.tl:25-26`.

2. Add an internal helper
   `local function distance_within(a: string, b: string, max_distance: integer): integer`.
   It is the current two-row Levenshtein of `distance()` (`fuzzy.tl:11-50`)
   with two changes:
   - it fills and reads `dp_prev`/`dp_curr` (indices `0..lb`) instead of
     allocating; because every read is of a cell written earlier in the
     same call (init loop writes `prev[0..lb]`; each row writes
     `curr[0..lb]` before the next row reads it), reused arrays carry no
     stale value into any read, and cells past `lb` are never read.
   - after computing each row `i`, it takes that row's minimum over
     `j = 0..lb`; if the minimum is `> max_distance` it returns
     `max_distance + 1` immediately (early abort). This is sound: once
     every cell of a row exceeds `max_distance`, every cell of every
     later row does too, so the final distance also exceeds it — the
     helper only substitutes a sentinel in the regime where the true
     distance is already past the threshold, and returns the exact
     distance whenever it is `<= max_distance`.
   Keep the existing early returns (`la==0`, `lb==0`, `a==b`) and the
   shorter-string swap.

3. In `find_similar` (`fuzzy.tl:74-120`), replace the
   `local dist = distance(query_lower, candidate_lower)` call at
   `fuzzy.tl:95` with
   `local dist = distance_within(query_lower, candidate_lower, max_distance)`.
   The surrounding `if dist <= max_distance then` guard, the
   length-difference gate (`fuzzy.tl:94`), the dedup-on-lowercase, the
   sort, and the limit trim all stay exactly as they are. Because
   `distance_within` returns the exact distance for every candidate that
   passes `dist <= max_distance`, the stored `distance` field and the
   whole result set (values, distances, order) are unchanged.

The public `distance()` function keeps its current body and contract
(it is a separate callable from the helper).
