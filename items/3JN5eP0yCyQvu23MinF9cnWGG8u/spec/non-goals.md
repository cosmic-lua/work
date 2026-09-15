Does not change who may review or what a review must do — `gitboard help
review`'s doctrine is untouched, including the builders/speccers exclusion this
verb now enforces in one step instead of three.

Does not remove `drop`, `claim`, `worktree` or `brief`, and does not change
their behaviour; `review` composes them. A caller who wants the steps
separately still has them.

Does not auto-publish, auto-spawn the reviewing agent, or make any provider
call. Gitboard stores no provider fact, and the agent spawn belongs to the
caller's own tooling.

Does not address the worktree bootstrap needing `--fetch` on a cold runtime
cache — the verb carries the flag through, and whether `worktree` should fetch
by default is its own question.
