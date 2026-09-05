## Evidence

`cosmic-lua/work` currently rejects a direct API merge of an accepted,
green-CI PR with a repository ruleset violation, not a review/CI gate:

    $ merge PR #26 (accept verdict recorded, CI green on the merge ref)
    405 Repository rule violations found
    Changes must be made through the merge queue

`gh.tl`/`gh` (the board's GitHub reach) and the GitHub MCP tools available
in this session have no merge-queue enqueue call — only a plain merge and
`enable_pr_auto_merge` (which itself failed separately: "Auto-merge is not
enabled for this repository. Enable it in repository Settings -> General ->
Pull Requests -> Allow auto-merge."). Neither path lands an accepted PR.

`gitboard help review`'s own accept instructions ("a main-repo PR lands by
enabling auto-merge (squash), never by merging directly") assume auto-merge
is available; it is not, on this repo, today. PR #22 (merged earlier the
same day, by `whilp` directly) suggests either the ruleset is new since
then, or a human merging through the actual web UI's queue button reaches
a path this session's tooling cannot.

## Change

Not this session's to make — needs one of, decided by whoever owns
`cosmic-lua/work`'s repository settings:

1. Enable "Allow auto-merge" (Settings -> General -> Pull Requests), so
   `enable_pr_auto_merge` succeeds and an accepted PR lands unattended, or
2. Grant the board's GitHub access (whatever token/App the `gh`/gitboard
   verbs and the GitHub MCP server run as) merge-queue write scope, or a
   distinct merge-queue-enqueue call gets added to the tooling, or
3. A human periodically merges (via the actual GitHub UI, which does know
   how to enqueue) the PRs an `accepted` board item names.

Until one of these lands, every `accept` verdict this system records ends
at "awaiting merge" and stays there — `gitboard`'s own model already
treats that as a normal, revisitable state (`next` names it: "finishing
beats starting"), so nothing is broken, but nothing finishes either.

## Non-goals

Bypassing the ruleset from this session (never attempted; 405 was read
and respected, not retried with a different method).
