## Access

read access to `cosmic-lua/work` — `.github/workflows/board.yml` and the
merge attempt on PR #26 cited below in Evidence.

## Evidence

[D38](../../cosmic/docs/decisions/d38-merge-queue-on-main.md) (`cosmic-lua/cosmic`'s decision record) decided a GitHub merge
queue on "main" once `whilp/cosmic` moved to the `cosmic-lua` organization
(the queue is org-repos-only), landing a main-repo accept by enabling
GitHub auto-merge rather than merging directly, and its rollout added a
`merge_group:` trigger to `cosmic-lua/cosmic`'s `.github/workflows/pr.yml`
so the gate runs on each queued candidate.

`cosmic-lua/work` is a separate repository under the same organization,
with its own `main` branch carrying real code (the gitboard tool's own
`_work/*.tl` source) landed via ordinary PRs — exactly the shape D38
describes. But attempting to land an accepted, green-CI PR here today
fails at the merge step, not review or CI:

    $ merge PR #26 (accept verdict recorded, CI green on the merge ref)
    405 Repository rule violations found
    Changes must be made through the merge queue

    $ enable auto-merge on PR #26
    Auto-merge is not enabled for this repository. Enable it in
    repository Settings -> General -> Pull Requests -> Allow auto-merge.

So a merge-queue-requiring ruleset is active on `cosmic-lua/work`'s
`main`, but the repo has neither auto-merge enabled (the only documented
entry point into the queue) nor a workflow trigger for it:

    $ git show origin/main:.github/workflows/board.yml | grep -A3 '^on:'
    on:
      push:
        branches: [main]
      pull_request:
      workflow_dispatch:

No `merge_group:` — unlike `cosmic-lua/cosmic`'s `pr.yml` after D38's
rollout. The repo is stuck half-migrated: the ruleset blocks a direct
merge, but nothing lets a PR into the queue that the ruleset requires.

## Change

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

## Non-goals

Re-deciding whether `cosmic-lua/work`'s `main` should queue at all (this
item only closes the gap between "a ruleset already requires it" and "the
workflow can actually run under it" — D38 already decided main-repo PRs
land via the queue's auto-merge path, generically, and this repo's `main`
is exactly that shape); the board branch's own direct-push landing (D38
explicitly excludes it, unaffected here); bypassing the ruleset from
tooling (never attempted).
