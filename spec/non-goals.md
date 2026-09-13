- The claim stays ONE field and stays a lease. `builders` is history
  beside it, not a replacement; `_work/health.tl`'s staleness rule
  reads `claim` and does not change.
- `gitboard spec` is not touched. The capture's third direction —
  detecting that a sidecar changed since the session read it — is a
  different failure (a lost refinement, not a lost review gate) and
  is not in this slice.
- `builders` is never cleared while the item is open, including on a
  return, a reject back to `plan`, or a re-pull. Whoever built stays
  disqualified as reviewer.
- No change to `next`'s verdict-line wording beyond what a correct
  `mine` count already produces, and no new verb.
- `_work/gitverdict.tl` is not touched: making `verdict` itself take
  `--session` and refuse the builder is item 3ICDOGbm's slice.
