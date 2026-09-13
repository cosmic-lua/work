- **`cosmic/coverage/init.tl` and `_build/casts_baseline.tl` are
  untouched.** The cast retire is 3ISPGV8z, blocked on the pin
  catching up; removing it here fails the cold build (Wrong turn
  above).
- The other three gaps (or-fallback shapes, closure carry-through,
  metatable<any>) are the research sibling's (3ISKgwfn).
- No other tl_patch entry moves; no pin bump; no `tl.tl` entry (the
  Evidence settles why).
- No behaviour change: the patch edits a TYPE declaration only; the
  compat-generated Lua for pack is untouched (`needs_compat` stays),
  so the fixpoint's byte-compare is unaffected.
- No header content is dropped — the compression rewords, it does not
  delete claims; the entry-form contract (`find` matches exactly
  once) and `_make/patch.tl` are untouched.
