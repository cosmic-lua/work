## Evidence

«xWSa_IIFM» established the right division of labor: green CI on an exact
head is the mechanical gate, and a reviewer runs only the diff's focused test
and mutation.  In the `cosmic --diff OLD` cycle, however, semantic Astra reviews
were started from local handovers before a PR/CI run existed.  The first
correction's pinned-cold-build failure was therefore discovered by a second
semantic review instead of by the mechanical gate.  After the final review,
both PR CI and merge-queue CI passed unchanged.

The gap is orchestration order, not a missing cosmic test and not a reason to
duplicate CI inside the reviewer checkout.

## Change

Update the builder/orchestrator and review brief text so a normal code handover
is reviewed only after mechanical checks have completed successfully on the
exact handed-over SHA:

- push/open or update the PR before spawning the semantic reviewer;
- confirm the PR head equals the handover SHA;
- wait for the repository's required checks to finish green; and
- if CI is unavailable by explicit item design, run the spec-named mechanical
  guards locally and label that fallback in the review brief.

A corrected head re-enters this same pre-review gate.  Red or running CI is not
semantic-review work: the orchestrator repairs or waits first.  The reviewer
still performs fresh semantic probes and one mutation after the gate.

Implement this as brief/doctrine text plus focused template tests, not provider
automation.  Touch at most three files under `_work/`, keep the change under
110 lines, and preserve Gitboard's rule that it neither queries nor records CI
state itself.

## Non-goals

No GitHub API calls in Gitboard, no new board state or evidence receipt, no
reviewer full-CI rerun, no change to merge/auto-merge behavior, and no product
repository changes.

## Access

cosmic-lua/work, read and write on a branch.  Read-only access to the completed
«xWSa_IIFM» item and the cited cosmic item history.
