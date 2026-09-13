- **The public contract is frozen.** Return shapes (`gsub` →
  `string | nil, string`; `split` → `{string} | nil, string`),
  no-match behavior (split yields one field; gsub returns text
  unchanged), the empty-match rejection, and the `nil`-from-function-repl
  "keep the match" rule all stay byte-identical. This is the Acceptance
  equality check's whole subject.
- **Do not touch `find`, `find_all`, `gmatch`, or `match`.** They keep
  `all_matches`/their own loop; `gmatch` reads `sp.m`/`sp.caps`, so its
  Spans are not surplus.
- **Do not delete `all_matches` or the `Span` record.** `find_all` and
  `gmatch` still return them, and `Span` is exported (re.tl:441).
- **No `cosmo.*`/engine change**, no new public function, no signature
  change on any exported name.
- **Do not widen the file past the cap.** Keep the change inside the
  measured headroom rather than reformatting neighbours to make room.
