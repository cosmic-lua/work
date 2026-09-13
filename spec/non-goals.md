- No binding change. `path.dirname`/`basename`/`join`, `unix.readlink`,
  and `Slurp`'s range semantics are frozen; the adapted `Barf` call and
  the two adapted `path.join(nil[, nil])` assertions move to their
  CURRENT calling convention because the OLD form no longer behaves
  that way — that is a syntax adaptation of a still-live function, not
  a binding change.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not touch `tool/lua/test_slurp_barf.lua` or
  `test_definitions_conformance.lua`; these three files are new,
  standing alongside them.
- Do not merge the three files; each is a distinct binding and stays
  under its own stamp.
