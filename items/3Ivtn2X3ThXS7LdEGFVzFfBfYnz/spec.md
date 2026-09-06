## Change

One invocation takes the ref snapshot more than once: counted with a
`git` wrapper on PATH against the live clone, `next` spawns
`for-each-ref` twice and `show ID` three times plus two `cat-file
--batch` sessions, where one snapshot and no `cat-file` would do.
Each extra `for-each-ref` is 11 to 20 ms. Find the callers
(`store.list`, `store.load`, `cache.open`/`guard`, `publish.touched_at`,
`claim_ages` in `_work/gitview.tl`) and make the store take ONE
snapshot per invocation — the digest it computes is kept on the store
and reused by every later open, load, and age lookup in the same
process — and make `show ID` read its item from the database
(`cachequery`) rather than `store.load`'s git read when the digest
matched. Measure with the wrapper before and after: `show` 1 spawn,
`next` 1, `show ID` 1, plus the bench medians in the PR.
