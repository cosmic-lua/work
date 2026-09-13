- `wip_refusal` itself stays: `cmd_move` is its live caller and the
  arrival/return semantics are untouched.
- `force`/`why` stay on every verb that can actually refuse (`move`,
  `done`, `review`, `land`): this deletes the escape only where there
  is nothing to escape.
- No new gate: whether `new --parent` under a phased leaf SHOULD be
  bounded is a design question for the flow review, not this cleanup.
- No change to `dephased_container` or the one-commit decomposition.
