- **Do NOT make `land` merge by another route.** The board tool
  issuing its own HTTPS request is the design; routing it through a
  session's harness credential is a different item and a much larger
  question about what the board is allowed to do on a session's
  behalf. This slice changes a MESSAGE.
- Do not add a flag, a retry, or a fallback path to `cmd_land`.
- `_work/gitland.tl` is not touched.
- No change to the 409 branch (added by #1323), to the generic
  branch, or to `is_merged`.
- No change to the `REFUSED (`/`ERROR (` prefixes — they are the
  shape an operator greps for.
