- No change to `re.Regex:match`, `re.Regex:find`, or `re.search`
  (module-level) — each is its own sibling capture, filed alongside
  this one and also blocked on `0YFj_out2`.
- No change to `re.compile` or `argon2.hash_encoded` — the census
  verified both tuple-exact; not in scope anywhere in this family.
- No change to `getopt.parse` — a different fix family entirely (a
  raise-candidate, not a tuple deviation), its own sibling capture.
- No cosmic-side (`cosmic-lua/cosmic`) change — `cosmic/re.tl` has zero
  callers of `:search`, so nothing there needs to move regardless of
  which mechanism this settles on.
