Measured 2026-08-19 on the board branch:

1. **`_work/gitverbs.tl`** (431 lines): `cmd_new`'s up-front gate (line
   76, `gate.wip_refusal(flow.board(all), nil, phase)`) runs before the
   parent is examined, yet the same function later de-phases a phased
   parent via `gate.dephased_container` (lines 81–87). Reorder: resolve
   `parent_item` first; when it is phased and its phase equals the
   child's entry phase, the mutation is net-zero — skip the up-front
   refusal (the rebase-path re-check stays, and 3I44Et1Z's arrival
   predicate already makes that half correct once landed). `cmd_attach`
   (line ~140) has the same shape for adopting an unphased capture
   under a phased leaf: same rule.
2. **`_work/gitgate.tl`** (257 lines): rather than special-casing in two
   verbs, give `wip_refusal` the knowledge — an optional
   `vacated: string` parameter (the phase the same mutation empties a
   slot in); when `vacated == to`, the arrival is net-zero and the limit
   has nothing to refuse. Both call sites pass the parent's phase (or
   nil when the parent is unphased/a container).
3. **Tests** (`_work/gitverbs_test.tl`): with a phase at its limit and a
   phased leaf parent, `new --parent` succeeds and the parent leaves the
   phase in the same commit (count unchanged); with a CONTAINER parent
   (no slot vacated) the same call is still refused; `attach` mirrors
   both.
