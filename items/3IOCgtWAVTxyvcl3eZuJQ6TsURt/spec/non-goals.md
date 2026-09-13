- **Do not start before the salvage child has landed.** It is a
  `blocked_by` edge, not a suggestion: deleting first loses the JSON
  conformance corpus, which `tool/lua/` does not otherwise have.
- **Do not touch `tool/lua/**`.** Porting is the other child's diff.
  If this slice finds something worth keeping that the salvage missed,
  that is a bounce (the inventory was wrong), not a widened diff.
- **Do not touch `.github/workflows/**`.** Neither workflow names the
  lane, so nothing there changes; if one does at pull time, bounce.
- **Do not touch the other four `test/tool/*` lanes** (`args`,
  `build`, `plinko`, `viz`) or any other `test/**` directory.
- **Do not change any binding.** The `cosmo.*` C boundary and
  `tool/net/definitions.lua` are frozen.
- **Do not touch anything in cosmic-lua/cosmic.**
- No other edit to the root `Makefile` beyond deleting line 399 — no
  reformatting, no reordering of neighboring `include` lines.
