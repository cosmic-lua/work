After `c5wU_p1n9` is done, and only then:

1. Dispatch the workflow on `main` with defaults
   (`gh workflow run release.yml`), or wait for the next 06:00 UTC
   cron; record the run id on this item.
2. Read the outcome of `compare against the previous release`:
   - green → this item is `completed`; note the release tag it
     published (the `pin-bump-1650` item wants it).
   - red on `re_match_log_line` again with `c5wU_p1n9`'s fix merged →
     that is a new finding: file it under `c5wU_p1n9`'s parent with
     this run's log lines, block this item on it, release the claim.
   - red on a different scenario → a new item with the scenario's
     compare line and the tie-break message; same block-and-release.
3. `perf_gate: false` is used ONLY when `c5wU_p1n9` ended by
   explicitly accepting the cost and moving the scenario baseline —
   then one dispatch with it, the run id and the reason recorded here.

No file in the tree changes under this item.
