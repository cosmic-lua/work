- Do not touch redbean's TLS server config (`tool/net/redbean.c`) or
  `net/https` — this issue is scoped to the client only, per its own
  "Independent of #184" framing, which this audit confirms is correct
  for the version-pin change itself (only the *verification* step
  touches redbean, and only after #184's fix).
- Do not add a Lua-visible option to pick the TLS version per call —
  the issue asks for the ceiling to simply track what Mbed TLS 3.6
  supports, not a new configurable knob; a per-call version knob is a
  separate, unasked-for feature.
- Do not fold this into the CA-bundle work (gh#148/`issue_148.md`) even
  though both touch `tool/net/lfetch.c`'s TLS setup — different lines,
  different mechanism, keep them as separate PRs to avoid a merge
  collision on the same file (see that spec's note on the same
  concern).
