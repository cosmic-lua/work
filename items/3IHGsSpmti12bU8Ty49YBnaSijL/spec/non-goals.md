- `_work/gitland.tl` is not touched. Its already-merged branch stays
  exactly as it is: it is the path for an item that reached `land`
  before its PR merged, which this change does not eliminate, and
  removing it would strand every item already sitting in `land`.
- No new field on `Item`. The merge sha rides in the commit subject;
  `verdict_head` keeps meaning the head that was JUDGED, not the
  commit that merged.
- `--force` is not added to `verdict`. The verb has none today, and
  the failing-read fallthrough means none is needed.
- A `request changes` or `reject` verdict does not read the PR. Only
  an accept asserts anything about landing.
- No change to the `gitboard-verdict:` verdict-line prefix, to the
  three verdict kinds, to `--enable`, or to the builder-distance
  refusal that runs before this.
- Review distance is unchanged: the accept must still come from a
  non-claimant session, and this runs after that refusal.
