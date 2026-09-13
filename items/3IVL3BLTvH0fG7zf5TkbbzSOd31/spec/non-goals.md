- **No change to any of the seven existing widen entries**, to
  `closure-root`, or to `closure-assigned-scan`. This adds one entry; it
  edits none.
- **No change to `widen_in_scope`, `assigned_anywhere`, `add_global`,
  `add_var`, or `specialize_var`.** The fix is one condition at one site.
- **No fork of tl.** The entry is a carried patch under the existing
  exact-once contract; if a pin bump moves the anchor, `--make fetch`
  must fail loudly and the patch be re-audited, exactly as the other
  entries do.
- **No new narrowing behaviour for locals.** A local narrow that carries
  today must still carry — that is what the third test pins.
- **No `global` declaration added, removed or changed in the tree**, and
  no edit to `cosmic/cosmic_debug_test.tl:8` or `cmd/cosmic/main.tl:4`.
- No edit to `teal_narrowing_test.tl`, `teal_nilflow_test.tl` or
  `teal_test.tl`; the closure-carry home is `teal_closure_test.tl`.
- No `docs/decisions/` record and no `docs/guides/checking.md` rewrite.
  This closes a hole the guides never promised was open; if the guides
  should say something about globals, that is its own item.
- No cast anywhere in the new code.
