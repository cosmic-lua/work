- no change to `store.publish`'s CAS shape or to `flow.LIMITS`.
- no change to the up-front (pre-push) `wip_refusal` in `cmd_new`/
  `cmd_move` — whether a net-zero `new --parent` should count its
  parent's de-phase is a separate item (filed as its own capture, with
  2026-08-19 evidence).
- no caller changes: the `from` conventions above are already in place.
