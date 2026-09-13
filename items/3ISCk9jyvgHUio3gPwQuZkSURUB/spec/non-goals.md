- **No code, and no PR.** Nothing under `tool/lua/`, `test/tool/net/`,
  `tool/net/`, `.github/workflows/**` or any `BUILD.mk` is edited by
  this slice. Its entire output is board state. A diff in
  cosmic-lua/cosmopolitan means the slice was misread.
- **Do not build or run `o//test/tool/net`.** The comparison is a read.
  The lane's pass/fail split is the parent's recorded evidence and is
  not re-measured here.
- **Do not repair, rewrite, or port anything now.** Writing one ported
  file "to prove it works" is the port slice's work, done under its own
  review.
- **Do not delete anything, and do not touch `test/tool/BUILD.mk`.**
  Retirement is `3IOCgtWA`, blocked on the whole container.
- **Do not change any binding.** The `cosmo.*` C boundary,
  `tool/net/definitions.lua`, and every return shape and error string
  are frozen. A test that will not port because a binding differs from
  redbean is a `retired` row and evidence for the table — never a
  reason to move the binding.
- **Do not touch anything in cosmic-lua/cosmic.** No pin bump, no type
  regen, no wrapper change.
- **Do not re-decide the parent's split.** Which checks are
  redbean-contract failures is settled in `3INxo51I`; this table records
  them, it does not relitigate them.
