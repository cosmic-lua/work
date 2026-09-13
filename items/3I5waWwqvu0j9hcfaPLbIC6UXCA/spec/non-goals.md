No new automated check that `TREES` covers every committed Teal tree — the
list is hand-maintained the same way it was when `_perf` and `_types` were
added, and adding such a check (if the gap recurs again) is separate future
work, not this slice.

No change to `_build/public_surface.tl` or any other gate — this slice is
`_build/casts.tl` only, matching the epic's own sizing for this wave.

No change to `_eval/*.tl` or `_fuzz/*.tl` themselves — their casts are
existing, justified sites (each already carries a `-- cast: <reason>`
comment); this slice only brings them under the gate, it does not touch
them.
