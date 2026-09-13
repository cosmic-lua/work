- No claim guard on a rightward move of a plan item somebody else is
  refining: `set_in_place` already refuses a live claim overwrite,
  and takeover semantics stay the existing `--force --why` rules.
- No `record_builder` from a refine claim: `set_in_place` does not
  record builders, which is what take-mode uses — a refiner stays
  eligible to review the eventual build.
- No change to `pullables`/`unheld`, the 4-hour do lease, or the
  review lease.
- No new item field: the existing `claim` carries the lease, and the
  phase says which lease applies.
- No edit to 3IUFODun's territory (`cmd_spec`, `store.tl`): this diff
  touches `cmd_move`, not `cmd_spec`, so the two merge independently.
