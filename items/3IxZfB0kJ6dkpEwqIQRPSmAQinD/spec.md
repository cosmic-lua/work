## Evidence

Two pullable items add lines to `cmd/cosmic/main.tl`, and neither spec
measured its headroom: `wc -l cmd/cosmic/main.tl` → `499` on main
(2026-09-06, orchestrator measure), one line under the 500-line cap
`cosmic --check lint` enforces with no exception.

- «jqgp_Bzmp» (piped non-tty stdin runs as a script, not the REPL)
  adds an `isatty` branch and a fall-through — several lines.
- «WgbG_UO99» (`--` pre-scan shadows an optional-arg flag's own
  terminator) adds at least a one-line comment at the `if a == "--"`
  branch, plus whatever the fix itself costs.

A builder pulling either hits the brief's own rule ("if the Change's
additions cannot fit under the 500-line cap, STOP now") on its first
`wc -l`. The extraction has to be its own change so both items can
land as the small diffs they are.

## Change

Move `parse_args` out of `cmd/cosmic/main.tl` into a new `_cli/parse.tl`
(`_cli.parse`), with no behaviour change. Measured (main, 2026-09-06):
`grep -n "^local function" cmd/cosmic/main.tl` places `parse_args` at
lines 87–313 — 226 of the file's 499 lines — and it is the only
block that size.

- `_cli/parse.tl` (new): `parse_args(): Options` — its current signature, unchanged (it reads the process arguments itself) — plus the
  `Options` record and every local that only `parse_args` uses (move
  them; the checker names each one — after the cut, `bin/cosmic --check
  types cmd/cosmic/main.tl` lists the unresolved names, and
  `--check types _cli/parse.tl` the ones the function needs). Locals
  used by both sides stay in main.tl and are passed as arguments, never
  duplicated. The module returns `{parse_args = parse_args, Options =
  Options}`; main.tl requires it as `local parse = require("_cli.parse")`
  beside its other `_cli.*` requires.
- `cmd/cosmic/main.tl`: the call site becomes `parse.parse_args()`;
  nothing else moves. Result: `wc -l cmd/cosmic/main.tl` ≤ 300.
- `_cli/parse_test.tl` (new): the argument cases `_cli/main_handlers_test.tl`
  or `cmd/cosmic/*_test.tl` already assert through `parse_args` move
  with it if they call it directly (`grep -rn parse_args --include=*_test.tl`);
  otherwise one case per flag family (script path, `-e`, `-l`, `--`,
  an optional-arg flag) asserting the same `Options` as before.
- Gate: `bin/cosmic --make ci`. The `.cosmic-coverage` floor gets the
  new file's row (name it in the PR body as the ratchet row added).

Then «jqgp_Bzmp» and «WgbG_UO99» refresh the count in their own Change
and pull as written, and «5P4r_VUqR» (`cosmic --find`) has its
dispatch line.

## Non-goals

Not the two fixes themselves — each stays its own item and its own PR.
