- No binding change. `unix.pledge`, `unix.sigsuspend`'s return shape,
  `unix.copy_file_range`, and every other function this file calls are
  frozen; the one rewritten line adapts to the CURRENT, still-live
  `unix.sigsuspend` contract, it does not change it.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not touch `tool/lua/test_signal.lua` or `test_unix_proc.lua`; this
  is a new, complementary file, not a merge into either.
- Do not split this file's content across multiple destination files.
  It is one source file with one verdict row in the inventory; it ports
  as one file, even though its content spans several `unix.*`
  sub-surfaces.
