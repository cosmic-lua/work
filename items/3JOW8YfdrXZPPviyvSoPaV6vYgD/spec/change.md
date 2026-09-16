When a spec asks a builder for a judgement rather than a change — "say in your
report whether X, and what it would cost; do not build it" — nothing says
where that judgement must land, so it lands wherever the builder happens to
write. On «E0cK_TZFH» it went into the pull request body. The fresh-context
reviewer, which reads the commit and the diff from a SHA, could not find it,
reported it as possibly lost, and spent calls looking.

The board deliberately stores no review prose, so a judgement that exists only
in a transcript is gone the moment the agent ends. A judgement in a PR body is
reachable by a human and not by the next reviewer.

Have the brief name the destination when the spec asks for a recorded
judgement: the commit message, so it travels with the change and any reader
of the SHA finds it. Say it once in the builder template rather than leaving
each spec to remember.
