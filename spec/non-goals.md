- No change to `re.Regex:search`, `re.Regex:match`, or `re.Regex:find`
  — each is its own sibling capture, also blocked on `0YFj_out2`. (Note:
  despite the near-identical prose, `re.search` is a genuinely
  different C function — `LuaReSearch`, not `LuaReRegexSearch` — so its
  C-side fix, if the arity-separation branch is chosen, is a separate
  edit from the method forms', not shared code.)
- No change to `re.compile` or `argon2.hash_encoded` — census-verified
  tuple-exact.
- No change to `getopt.parse` — a different fix family (raise
  candidate), its own sibling capture.
- No cosmic-side (`cosmic-lua/cosmic`) change — zero callers found;
  nothing there needs to move regardless of which mechanism this
  settles on.
