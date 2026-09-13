`gitboard worktree`: add a `--quiet` (or default-quiet with `--verbose`
to opt back in) mode that suppresses the per-file `compile`/
`compile-batch` lines from the underlying `--make fetch`/`--make build`
run, surfacing only the summary lines each stage already prints
(`fetch: PASS (N pins)`, `build: PASS (N files, 1 binary)`) plus any
failure output in full. A failed bootstrap still prints everything
needed to diagnose it; a successful one costs a handful of lines
instead of hundreds.
