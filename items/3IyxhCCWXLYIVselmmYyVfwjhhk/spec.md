## Evidence

`gitboard take ID` for a pull is refused while any diff awaits a verdict the caller could give ("1 diff(s) await a verdict you can give and outrank this take — verdicts before new work"), but the review claim on that diff is itself refused while its CI runs. So in the window between a PR opening and its CI finishing (10–25 minutes on cosmic-lua/cosmic, 3–5 on cosmic-lua/work) no pull can start at all: work pass 5 hit it three times in one hour (7Vds behind cosmic#1784, ZD1x behind work#73 and then behind cosmic#1785), each time with a free agent slot and a ready brief, each time waiting on a check the orchestrator could neither claim nor influence. The rule's purpose — a diff never waits on a verdict because everyone pulled new work instead — is served by a review that CAN be claimed; a review that cannot be claimed yet is not one anyone is skipping.

## Change

`take`'s verdicts-before-pulls refusal counts only diffs whose review is claimable now: `ciobs.current_state` green (or unknown when no observation exists), not running. A diff whose CI is running is listed in the refusal's alternative line instead ("1 diff in CI: 3Iyp6ndW — its review opens when CI finishes"), and the pull proceeds. `_work/gittake_test.tl` gains: a doing item with a PR whose cached CI state is running does not block a pull; the same item green does.

## Non-goals

No change to the review claim's own CI gate; no change to `next`'s ordering.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

With one PR in CI and one item pullable, `gitboard take <pullable>` succeeds and its verdict line names the in-CI diff.
