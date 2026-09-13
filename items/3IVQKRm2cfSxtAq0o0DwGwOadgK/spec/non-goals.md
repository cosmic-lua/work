- **No behaviour change.** The loop widen is sound and stays. This
  item documents and tests what landed; it does not narrow or widen
  the rule.
- No change to the entry's `find`/`replace` beyond the comment text
  inside `replace` — and note that touching `replace` changes the
  patched bytes, so `--make fetch` must be re-run and the resulting
  `o/3p/tl/tl.lua` re-verified as deterministic.
- No new patch entry.
