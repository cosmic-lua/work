Closed, no code change. The tree-wide-breakage premise was re-verified
independently (patch re-derived from scratch since branch `3IpBKtB8`
was gone; `o/bin/cosmic --check types cosmic/shm.tl` reproduces the
same 6 errors — read/load/atomic/cmpxchg/wait/mapshared — and
`o/bin/cosmic --make check` reproduces the same 3 additional failures
— `_make/policy_test.tl:376`, `_eval/score_test.tl:143`,
`_fuzz/shrink.tl:41` — the original spec named).

Of the three options weighed: a call-site-scoped mechanism outside
`3p/tl_patch`'s shared-function-body patch already exists and is
already in use — `cosmic/sqlite/extras.tl`'s 2 sites already carry a
working `-- cast: ... / (verdict as string)` fix, lint-compliant under
`cast-justify` and matching the checker's own "cast after a guard"
hint. Genuine ok-keyed flow narrowing in the checker (discriminated
narrowing of a pcall tuple keyed to its own boolean) would be a real
fix but is a materially larger checker-design change needing its own
decision record first, with no concrete forcing need beyond these 2
already-solved sites.

Closing as not viable at the patch-entry granularity: the 2 sites this
item targeted already work correctly with their existing casts — no
further change is needed here.
