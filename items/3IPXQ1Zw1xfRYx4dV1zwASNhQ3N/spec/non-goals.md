- **No library file.** A `check.must` in library code would throw, and
  AGENTS.md forbids it. Only `_test.tl` and `_example.tl`.
- **No checker change.** `3p/tl/tl_patch.tl` and `_make/patch.tl` are
  untouched; this slice is edits at sites.
- **Do not change what a test asserts.** The wrap makes the type honest;
  a test that passes today must still pass, testing the same thing.
- **Do not add a cast.** `check.must` replaces `assert(x) as T`, never
  the other way round.
- **Do not fix a site the checker will close.** That is what 3IPXM4K2
  did and why this item waits on it: a guard the author already wrote is
  not work, and wrapping it anyway makes the census unattributable.
