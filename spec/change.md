**This item writes and lands the checker patch only, for the
NON-zero-arity gap (`sqlite/extras.tl`'s 2 sites). It does NOT delete
either of those 2 casts, and does NOT touch `_teal_engine.tl:256`** —
see Non-goals; the cold-build rule (CLAUDE.md) and the reclassification
finding above are why.

1. **Fetch and locate the anchor.** `bin/cosmic --make fetch` unpacks
   the pinned tl source to `o/3p/tl/tl.tl` (already patched with
   `narrow-pcall-zero-return`). Find `pcall`'s special-case handler —
   the same one `narrow-pcall-zero-return` (`3p/tl/tl_patch/narrow.tl`)
   already edits — and read its CURRENT (already-patched) shape.

2. **New file `3p/tl/tl_patch/pcall_return.tl`** (not `narrow.tl` — see
   Evidence on headroom), one entry, in the same `find`/`replace`/`note`
   shape as every entry in this directory:

   ```teal
   return {
     ["narrow-pcall-return"] = {
       file = "tl.lua",
       note = "<upstream issue ref>: a known-signature, non-zero-arity "
         .. "pcall(f, ...) types its failure arm as `any` instead of "
         .. "admitting the raised type alongside f's own success type",
       find = [=====[<exact snippet, from the fetched, ALREADY-patched
         o/3p/tl/tl.tl, around pcall's special-case handler — this must
         match the tree AFTER narrow-pcall-zero-return's own edit, not
         the pristine upstream source>]=====],
       replace = [=====[<the same snippet plus the widening fix>]=====],
     },
   }
   ```

   The fact to add: for a known-signature, NON-zero-return-arity
   callee (the case `narrow-pcall-zero-return` does not already
   handle), type the call node's SUCCESS-arm slot 2 from the callee's
   own first return type (confirmed this already happens today — do
   not re-derive it), and widen the DECLARED type across both arms to
   a union of that success type and whatever type a raised failure
   carries (Lua leaves the raised value's type unconstrained) — a
   caller narrows by checking `ok` first, same as today. Where the
   callee's type is not known at the call site (`any`-typed or
   computed dynamically), leave today's behavior untouched — confirmed
   this case already hard-fails to type-check independent of pcall (an
   `any`-typed callee is "not a function: <any type>" today), so no
   extra fallback code is needed for it. `find` must match the pinned,
   already-patched `o/3p/tl/tl.tl` exactly once (D21's exactness rule);
   if it does not, report the mismatch rather than force a near-match.

3. **New file `cosmic/teal_pcall_test.tl`** (not `teal_test.tl` — see
   Evidence on its zero headroom), following the shape of
   `test_pcall_zero_return_canary` (`cosmic/teal_test.tl:476-500`) and
   `test_narrowing_canary`: a snippet that calls `pcall` on a
   known-signature, non-zero-arity function and reads the success
   return WITHOUT a cast; a second case confirming an `any`-typed
   callee is unaffected (still fails to type-check independent of this
   patch, or still types `(boolean, any)` if it does not fail — verify
   which during refinement's own probe, not assumed here).

4. **Open the upstream issue.** Per D21's maturity clause: open an
   issue in `cosmic-lua/cosmic` (this session's GitHub access has no
   cross-org reach to `teal-language/tl` — see AGENTS.md's own note on
   this) describing the gap, referencing `docs/design/casts.md`'s
   "pcall return shape" section and `sqlite/extras.tl`'s 2 sites.
   Record its number in the patch entry's `note` field.

Gate with `bin/cosmic --make ci`, including the new canary.
