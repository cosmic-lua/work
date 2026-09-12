## Evidence

`cosmic --make test` prints the same `record <target>` line whether it
actually ran a test file or replayed a cached result, so a green run and
a skipped run are indistinguishable from the output.

This is not a cosmetic complaint. Two agents lost time to it in one
session, in opposite directions:

- A builder mutation-testing a guard saw `15 tests: 15 passed` against a
  state it had just proven was broken. The pass was a replay. It caught
  this only by running the compiled `o/..._test.lua` by hand and getting
  the opposite answer — roughly 40 minutes, and the conclusion it first
  drew from the false green was wrong.
- The same builder later saw `ci: FAIL (coverage)` persist across
  repeated runs after the defect was fixed, replaying a recorded FAILURE
  with zero `record` lines in the log and nothing left that would ever
  invalidate it.

The caller independently hit the ambiguity from the other side: a
mutation that DID fail correctly could not be distinguished, from the
output alone, from one that had silently replayed — so the result had to
be re-verified by hand before it could be trusted.

Caching is right and should stay: it is what makes the gate fast. The
defect is that its effect is invisible. A cached result is a statement
about a previous run, and the output presents it as a statement about
this one.

The cost concentrates exactly where correctness matters most — mutation
testing, which the review doctrine requires of every change, and which
depends entirely on telling a real pass from a replayed one.

## Change

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

## Non-goals

Not changing what is cached, when a recording is invalidated, or the
`--- reads:` mechanism that feeds it. Not making the gate slower by
disabling caching anywhere. Not changing the `ci` verdict line's format.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
