- **The 405 classification stays as it is.** The capture notes that
  branch protection and closed PRs report 405 into the generic
  "re-run land once the cause clears" branch. That is a real second
  seam and it is 3I8lUm1r's; only 409 is in scope here, because the
  `sha` guard is what makes 409 reachable at all.
- No change to `cmd_verdict` or to what `verdict_head` means: it is
  the head the reviewer judged, written by the verdict, read here.
- The already-merged branch keeps ending the item `completed`. A
  merge cannot be undone; the fix is a loud record, not a refusal.
- No new field on `Item`.
- `--force` keeps its existing meaning on `land` and skips the new
  refusal along with the others.
- No change to the `gitboard-land:` verdict-line prefix.
