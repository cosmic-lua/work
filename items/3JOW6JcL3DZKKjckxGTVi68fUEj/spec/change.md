Nothing in the builder or review brief tells a spawned agent how to wait for
a long-running gate, and the default behaviour loses work. An agent that
starts `bin/cosmic --make ci` and lets its turn end returns to a caller with
no verdict and, in one case this session, an uncommitted tree that read as
"the agent finished having done nothing". The recovery cost about 20% of one
build.

The rule that works: never end a turn with a gate still running. Run it in
the foreground with an explicit long timeout, or if it is backgrounded, poll
it to completion inside the same turn. A partial version of this
countermeasure — background plus a wait loop, but without an explicit timeout
on the polling call — still failed, because the poll itself was
auto-backgrounded. The timeout is not optional detail; it is the part that
makes the rule hold.

Put it in the brief templates' environment section so every spawned agent
gets it, rather than in each caller's supplementary prompt. Six agents in one
session needed to be told this by hand.

While there, the same section should say to read the final `ci: PASS` /
`ci: FAIL` verdict line and not to pipe the gate through `tail` without
`set -o pipefail` — the repo's own AGENTS.md says so and the brief does not.
