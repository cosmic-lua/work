## Evidence

`gitboard worktree ID` bootstraps the new checkout by running a full
`--make fetch` + `--make build`, and prints every step verbatim to
stdout: a `fetch` line per pin, then a `compile-batch`/`compile` line
per source file. Measured live, 2026-09-07, orchestrating this
session's own wave: a single `cosmic` worktree bootstrap printed roughly
650 lines (one per compiled module, `_build/*`, `_cli/*`, `_make/*`,
`cosmic/**`, `3p/**`); a `work` worktree bootstrap printed a shorter but
still multi-hundred-line list. This output lands directly in the
ORCHESTRATOR's own context on every single `take`+`worktree` pair — nine
worktrees this wave, nine full dumps — pure token cost with no
information content beyond "it built" (the one line that matters,
`build: PASS (N files, 1 binary)`, is buried at the bottom). Worked
around this run by redirecting each `worktree` call to a file and
tailing the last few lines, but that's an orchestrator-side workaround,
not something the tool offers.

## Change

`gitboard worktree`: add a `--quiet` (or default-quiet with `--verbose`
to opt back in) mode that suppresses the per-file `compile`/
`compile-batch` lines from the underlying `--make fetch`/`--make build`
run, surfacing only the summary lines each stage already prints
(`fetch: PASS (N pins)`, `build: PASS (N files, 1 binary)`) plus any
failure output in full. A failed bootstrap still prints everything
needed to diagnose it; a successful one costs a handful of lines
instead of hundreds.

## Non-goals

Not changing what `--make build`/`--make fetch` print when run directly
by a human or in CI — only `gitboard worktree`'s own wrapping of them
for an orchestrating session. Not touching `--make ci`'s own output
shape.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
