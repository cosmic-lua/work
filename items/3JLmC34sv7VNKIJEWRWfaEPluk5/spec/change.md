Built and open as cosmic-lua/cosmic#1859; this item tracks it through
review and landing.

`.github/workflows/pr.yml`: drop `needs: build` from the `repro` job so
the two cold builds run concurrently. `repro` uploads its own converged
binary as `cosmic-repro`; a new `compare` job (`needs: [build, repro]`)
downloads both artifacts and byte-compares them, carrying the
`reproducible: PASS` verdict that used to print inside `repro`.
`compare` declares the same `container:` and non-root builder as every
other Linux lane, so `_build/workflows_test.tl` needs no
`UNCONTAINERISED` entry and stays at its current 499 lines — a two-line
entry there would have put it at 501 and failed the 500-line cap.

The gate was never the critical path. On run 34798623808 `ci` ended at
+182s while the run ended at +521s, because `repro` sat idle waiting on
`build`. That dependency bought one thing, the bytes to compare:
`grep -n "cmp /cosmic-first" .github/workflows/pr.yml` finds the single
cross-job use, and repro's fetch, its cold build at `$HOME/repro` and
its idempotent-refetch check read nothing `build` produced.

Measured after, on the PR's own run 34928907285: 521s -> 265s, 49%, all
six jobs green, `compare` byte-matching the two binaries.
