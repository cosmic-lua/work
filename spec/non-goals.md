- No change to `re.Regex:search`, `re.Regex:find`, or `re.search`
  (module-level) — each is its own sibling capture, also blocked on
  `0YFj_out2`. (`:search` shares the SAME C function as `:match` — see
  above — so the two C-side fixes are one edit; coordinate, don't
  duplicate.)
- No change to `re.compile` or `argon2.hash_encoded` — census-verified
  tuple-exact.
- No change to `getopt.parse` — a different fix family (raise
  candidate), its own sibling capture.
- No edit to `cosmic/re.tl` in this item — that is
  `cosmic-lua/cosmic`, a different repo; note the follow-up, don't make
  it here.
