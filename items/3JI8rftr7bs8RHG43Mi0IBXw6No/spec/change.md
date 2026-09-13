Format 6 lands as one change: cosmic-lua/work#171 (`impl/gitboard-format6`),
brought to the design in `docs/design/storage.md` and reviewed as a whole.
The six engine children this container filed (codec, reader, writer, claims,
drafts and log entries, fsck and init), the connector plan and the retire
are folded into that PR and closed `not-planned` with this item as their
successor; pin, run and contention stay live and depend on it.

What "ready" means, in the review's terms (the two reviews on the PR, and
the findings file they consolidate into): every blocking finding fixed
(B1–B12), every should-fix either fixed or answered on the PR, CI green on
the head, and one final fresh-context review of the whole diff against
`docs/design/storage.md` with no blocking finding — then the owner approves
and the merge queue lands it. The decisions that settle the open findings:

- the connector target is ChatGPT Work's GitHub connector with the
  three-call vocabulary; the requirement is EQUIVALENCE — a transition
  publishes the same tree and the same message on either executor, so the
  `Gitboard-Author` trailer rides both paths and is the author of record
  for history (storage.md, `## One commit, one mutation`);
- the bounded set is the design's — a new `take` against the doing bound,
  the lane mint, `depend`'s cycle walk, `attach`'s depth walk — with `done`
  and `rank` recording the item paths their gates read, and revalidation
  calling the verbs' own gates against a view built from the new head;
- the freeze is verified by a refused-push probe (a throwaway ref created,
  a tip updated, the throwaway deleted, under each fenced namespace; every
  attempt must be refused; the refusals recorded in the checkpoint) on top
  of the owner's own confirmation of the ruleset;
- `migrate6 publish` is wired: staged fast-forward pushes `--limit N`
  apart, the complete ref-set recheck, the atomic activation push;
- the retire is inside the PR: the format-5 reader and writer, claim
  batches, `board/seq`, the pack-specific single-head code and
  `experiments/`; `singlehead_calls`, `singlehead_plan`'s save/load and
  `singlehead_literal` stay as the connector substrate. Consequence: the
  release cannot be pinned before activation, so release → migrate6 from
  that binary → activation → pin bump, back to back;
- old refs stay as the archive, never deleted; the 19 legacy `result:`
  digests stay as they are and `migrate6 plan` names every unmapped
  evidence value;
- five publish retries with no backoff, the retry rate measured at 2, 4
  and 8 writers before the cutover (the contention child).
