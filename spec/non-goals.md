- No change to the no-match/error reachability itself, only the tuple
  shape.
- No change to `re.compile` (already exact) or `getopt.parse`/
  `argon2.hash_encoded` (separate captures/rows).
- Coordinate with the sibling `re.Regex:match` and `re.search`
  captures before landing — same C function, same annotation block
  family.
