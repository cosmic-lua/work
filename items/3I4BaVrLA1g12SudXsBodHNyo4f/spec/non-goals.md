- **WIP adherence over time is not in scope.** The capture names it,
  and it needs a per-instant reconstruction of the whole board rather
  than per-item intervals. This slice is dwell plus counts; the
  adherence series is its own item once these two are trusted.
- No new dependency, no JSON output, no file written. `stats` prints
  and exits.
- `_work/health.tl`'s staleness rule is untouched — it reads an
  item's last commit, not this.
- No change to any existing commit-subject format. This slice READS
  the grammar; changing it would invalidate the history it parses.
- No change to `status`, `tree`, `next` or their output.
- `_work/store.tl` gains the optional parameter and nothing else.
