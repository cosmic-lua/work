- No body changes. `parse_rule`, `validate_key`, `validate_rule`, `validate`,
  `index`, `match` and `auth_header` keep their current logic exactly —
  in particular `validate_key`'s fail-open guard (a malformed port must stay a
  validation error, never a silent widening to "any port") is untouched.
- No new nil handling in `cosmic/quicksand/proxy/serve.tl`. Its two `rules.match`
  calls compile unchanged; do not add guards around them.
- `cosmic/quicksand/proxy/http.tl` belongs to item `3I9Tko2h` (PR #1306), which
  walls this file off in turn. The two are file-disjoint and land in either order.
- `cosmic/url.tl` carries the same declaration shape and is NOT in scope:
  `port: integer` at `:113` and `:233`, and `local port: integer = nil` at `:132`.
  Leave all three alone; that is separate work, not this slice's.
- No cast sites move, so `_build/casts_baseline.tl` must not change — if a
  ratchet gate does complain, run exactly the regen command its failure message
  prints and commit the result, never a gate weakened any other way.
- No doc-comment rewrites beyond leaving the existing ones alone: `:28` and
  `:43-45` already state the nil contract correctly.
