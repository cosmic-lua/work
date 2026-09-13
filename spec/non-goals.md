- **No tl patch and no upstream proposal.** `3p/tl/tl_patch.tl` and
  `_make/patch.tl` are not touched: the probe above showed no site here
  needs a checker change, so the `math.type` narrowing this item was
  opened around is not built, not proposed, and not filed. If a future
  site does need it, that is a new item.
- **No other cast reason moves.** `git ls-files '*.tl' | xargs grep -h
  -- "-- cast: " | grep -vc "number to integer"` is 389 before and 389
  after (the total falls 402 -> 389 because only this bucket leaves). In particular the `-- cast: dynamic E* lookup` in
  `cosmic/errno.tl` and the `from any` sites in `cosmic/instrument.tl`
  stay exactly as they are.
- **No behaviour change outside `serve.tl`'s log line.** The five
  stale-cast deletions and the six `math.tointeger` wraps compile to
  the same or equivalent Lua; `instrument.tl`'s `or 0` defaults are
  preserved deliberately so a malformed record still reads as 0.
- **Do not touch `_types/types_gen.tl` or anything else under
  `_types/`** beyond the two field types on `_types/gentl.tl:199-200`.
  The generated `.d.tl` files are build output and are not committed.
- **Do not touch `whilp/cosmopolitan`.** No `definitions.lua` change is
  implicated; `cosmo.ParseIp` is already annotated correctly.
- **Do not lower any other baseline row.** Only the six rows named
  above move, and they move because casts were removed — never by
  hand-editing `_build/casts_baseline.tl`.
- **Do not widen `AGENTS.md` or write a decision record.** Deleting a
  cast bucket settles no tradeoff.
