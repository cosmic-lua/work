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

## Change (sketch — the refine owns the shape)

Move one self-contained block out of `cmd/cosmic/main.tl` into a
sibling module the dispatcher already owns (`_cli/`), sized to leave
at least 30 lines of headroom, with no behaviour change — the
candidate is whichever top-level function the refine measures as
longest and least entangled (`grep -n '^local function' cmd/cosmic/main.tl`
gives the boundaries). Gate: `bin/cosmic --make ci` ends `ci: PASS`;
`wc -l cmd/cosmic/main.tl` ≤ 470. Then «jqgp_Bzmp» and «WgbG_UO99»
state the refreshed count in their own Change and pull as written.

## Non-goals

Not the two fixes themselves — each stays its own item and its own PR.
