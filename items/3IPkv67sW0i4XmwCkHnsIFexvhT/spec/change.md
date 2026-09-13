1. Measure first, the way the `or` rule was measured: rebuild the
   throwaway strict checker from `docs/design/nil-flow.md`'s
   `## Method`, add one further edit that treats `break`, `goto`,
   `error()` and `os.exit()` as narrowing exits, re-run the same scan,
   and report the delta and that the new site set is a strict subset.
2. If the yield justifies it, add the edit to `3p/tl/tl_patch.tl` as a
   seventh narrowing key with a pinning test in
   `cosmic/teal_narrowing_test.tl`, and take the same measurement
   upstream to teal-language/tl.
3. If it does not, say so with the number and close the item — a
   measured no is the deliverable.
