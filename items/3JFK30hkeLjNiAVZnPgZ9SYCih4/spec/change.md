Distinguish the two in the output: a line that says the result was
replayed from a recording, rather than the same `record <target>` line a
real run prints. The words matter less than that they differ and that a
reader can tell without knowing the runner's internals.

Add a way to force a run regardless of the recording — the escape hatch
that today requires knowing to delete `o/<path>.test.*` by hand, which
`AGENTS.md` documents but which nothing surfaces at the moment a reader
is staring at a suspicious pass.

Add a case asserting the two paths print different things: a first run
that records, and a second identical run that replays, produce
distinguishable output.
