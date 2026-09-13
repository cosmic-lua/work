`skills/work/SKILL.md`, in the `--routine` section's friction-log
bullet list (the "the friction log" paragraph, step 1: "open the log
before the first board verb"): no wording change — the sentence
already says this. Add one clause making the ordering constraint
concrete and self-checking: name the exact first verbs a bootstrap
pass runs (`sync`, then `show`/`next`) and state that the friction log
file must exist on disk before the first of `next`, `take`, `attach`,
or `compare` — i.e. `sync` and a plain `show` (board-wide, no ID) are
the only verbs allowed before the log file is created, since bootstrap
and sync produce no board state to log yet.
