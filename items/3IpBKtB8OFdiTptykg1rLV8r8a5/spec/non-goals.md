- **Do not touch `shm.tl:146,171`** — already closed by PR #1725
  (`narrow-pcall-zero-return`); re-verify they are absent from
  `cast-sites.tsv`'s "pcall return shape" rows before starting, and
  STOP if they are not (a premise this respec relies on would be
  false).
- **Do not touch `_teal_engine.tl:256`** — evidence above reclassifies
  it as a nominal-record mismatch (`Result` vs `TlResult`), not pcall
  return typing; resolving it is a different item's scope, filed
  separately when `docs/design/cast-sites.tsv` is next audited.
- **Do not delete either `sqlite/extras.tl` cast in this PR.**
  CLAUDE.md's cold-build rule: a new patch entry is exactly "a source
  that needs the tree's own checker" — `_build/coldbuild_test.tl`
  type-checks generation 1 with `bin/cosmic.pin`'s CURRENT release
  checker, which does not carry this new entry yet, so code relying on
  it fails only a cold build. Land the patch and its canary first;
  deleting the 2 casts is separate follow-on work that must wait for a
  `bin/cosmic.pin` bump to a release built from a tree carrying this
  patch, and, when filed, must carry a `blocked_by` edge on that
  pin-bump item.
- Not modifying `3p/tl/tl_patch/narrow.tl` or `cosmic/teal_test.tl` —
  the new entry and canary live in their own new sibling files
  instead (see Change); this item does not need either file's
  existing content to change.
