- `_work/action.tl` is not touched. Widening `reviewable` past the
  single `claim` field is item 3IE6ttNh's slice; this one makes the
  claim honest at the two points that write it, and the two slices
  compose without either depending on the other.
- `--session` stays OPTIONAL on `verdict`. Making it mandatory would
  refuse every existing repair path and is a separate decision.
- No change to the board's commit identity (`_work/store.tl`
  GIT_DEFAULTS) — the reviewer rides in the subject, not the author.
- No change to the `gitboard-verdict:` or `gitboard-move:` verdict
  line formats.
- The three verdict kinds, their target phases, and the `--enable`
  requirement on a non-accept do not change.
- `land` is not touched; gating the move into it is item 3ICDNqdv's.
