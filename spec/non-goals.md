- Not changing `verdict_line`'s signature or behavior for any other
  verb — the fix is local to `brief`'s success path, not a stream
  change (stdout vs. stderr) applied globally.
- Not suppressing a REFUSAL's verdict line under `--body-only` — a
  refusal has no body to separate it from, so it always prints.
- Not changing what `unfilled(scan_body)` reports or how `tail_note`
  is worded — `--body-only` only decides whether that line prints, not
  what it says when it does.
