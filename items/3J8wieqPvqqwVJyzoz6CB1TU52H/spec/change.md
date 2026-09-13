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
