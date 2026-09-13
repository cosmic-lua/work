1. `.github/workflows/board.yml`: add a `merge_group:` trigger alongside
   `push`/`pull_request`/`workflow_dispatch`, mirroring D38's change to
   `cosmic-lua/cosmic`'s `pr.yml` — no job changes needed (the workflow's
   single `board` job already runs the same `--make ci` regardless of
   trigger).
2. Not this item's to do, and not achievable in code: `cosmic-lua/work`'s
   repository setting "Allow auto-merge" (Settings -> General -> Pull
   Requests) needs enabling by whoever holds admin rights on the repo —
   this is what actually lets `enable_pr_auto_merge` succeed and a PR
   enter the queue. Until it is, step 1 alone gates queue runs correctly
   but nothing can trigger one.
