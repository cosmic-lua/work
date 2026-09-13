Either: (a) `gitboard verdict` (and `take`) detect a rejected push and
automatically fetch+rebase+retry (bounded, e.g. 3 attempts) before
reporting failure, so a transient race self-heals without a human or
orchestrator noticing an inconsistent local state; or (b) `gitboard
help review` and the emitted review brief instruct each reviewer to
clone its OWN board checkout (`git clone <board-repo> --branch board
/tmp/review-board-<handle>-<session>` + `bin/cosmic --make build`)
rather than sharing the orchestrator's, mirroring the "one fresh
worktree per agent" rule builders already get for the PRODUCT repo.
(a) is the better fix on its own (it also protects the orchestrator's
own sequential `take`/`verdict`/`done` calls against a concurrent
session, which (b) does nothing for); (b) is complementary and cheap
to also do.
