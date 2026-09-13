- **No `cmd_verdict` change** — verdict-implied moves carry their own
  rules and already record who judged.
- **No staleness check inside the guard** — a dead session's claim is
  taken over with `--force --why`, exactly like the replacement path;
  lease-aware offering is `next`'s job (3ISONrYo) and stays there.
- **No change to `is_return`'s claim-clear or verdict-clear** for the
  moves that pass the guard; no WIP rule changes — returns stay
  exempt from limits.
- **No change to `set_in_place`, `--claim` semantics, or the
  to-do/to-check claim fill.**
- **Frozen:** the `gitboard-move:` verdict-line format; `--force
  --why` as the takeover spelling; `session.resolve`'s derivation
  order.
