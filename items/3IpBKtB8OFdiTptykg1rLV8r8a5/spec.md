## Evidence

Re-run 2026-09-03 against `origin/main` (`96afd807`), then re-verified
2026-09-06 by a builder attempt that stopped before editing (see
below) — the class has moved since this item was first written.

**Two of the original 5 sites are already closed.** Board item
`lT1A_fWo4`-adjacent PR #1725 ("narrow-pcall-zero-return") landed a tl
patch entry AND its own canary (`cosmic/teal_test.tl:476-500`,
`test_pcall_zero_return_canary`) for the ZERO-RETURN-ARITY subclass —
`shm.tl:146,171`'s two sites are exactly this shape
(`pcall(raw.write, ...)`/`pcall(raw.store, ...)`, both zero-return
callees) and are gone from `docs/design/cast-sites.tsv`'s "pcall
return shape" rows as of that PR. Confirm before building:

    git show origin/main:docs/design/cast-sites.tsv | awk -F'\t' '$3=="pcall return shape"{print $1":"$2}'

**A second builder attempt traced the checker directly and found the
remaining 3 sites are not one uniform gap either:**

- `cosmic/sqlite/extras.tl:63,106` — the real, still-open gap: a
  known-signature, NON-zero-arity callee's success return IS already
  typed from its own signature today (confirmed empirically:
  `pcall(known, 3)` types slot 2 as the callee's real return type, not
  `any`, when the callee's signature is known at the call site). The
  actual missing piece is narrower than this item originally framed
  it: slot 2's declared type has no admission for the FAILURE arm
  (the raised-error type), which is exactly why these two sites still
  cast the failure-arm read to `string`.
- `cosmic/_teal_engine.tl:256` — likely a DIFFERENT class entirely, not
  pcall return typing at all: the cast is a nominal-record mismatch
  between tl's own `Result` and cosmic's structural `TlResult` mirror
  (`local result = result_or_err as TlResult`), unrelated to how
  `pcall` itself types its returns. Flagged here as a finding for
  whoever next audits `docs/design/cast-sites.tsv`'s classification —
  not resolved by this item's Change, and not to be attempted here
  (see Non-goals).

**The file-cap facts this item's original Change assumed no longer
hold — both anchor files PR #1725 already touched are now at or past
their headroom:**

    $ wc -l cosmic/teal_test.tl
    500 cosmic/teal_test.tl
    $ wc -l 3p/tl/tl_patch/narrow.tl
    467 3p/tl/tl_patch/narrow.tl

`cosmic/teal_test.tl` is AT the 500-line cap exactly (its last 25
lines, 476-500, are PR #1725's own `test_pcall_zero_return_canary`) —
zero headroom for a new canary. `3p/tl/tl_patch/narrow.tl` has 33
lines of headroom; a builder drafted the actual `narrow-pcall-return`
find/replace/note entry needed here (both `find` and `replace` must
carry the FULL ~15-line `narrow-pcall-zero-return` anchor block
verbatim, per D21's exactness rule, since that entry's block is what
the fetched, already-patched `o/3p/tl/tl.tl` now contains at the
relevant location) and it came to 54 lines — 21 over the available
headroom.

**This is not actually a blocker — it is `3p/tl/tl_patch/`'s and
`cosmic/teal_*_test.tl`'s own designed escape valve.**
`_make/patch.tl`'s own doc comment states the mechanism directly: "a
`3p/tl/tl_patch/` directory whose `*.tl` files each hold entries in
the same format (capacity comes from splitting, not a bigger cap)...
one namespace across the whole set, applied in sorted-name order" —
i.e. a NEW file in `3p/tl/tl_patch/` holding this one entry applies at
exactly the same position sorted-by-entry-name would put it in
`narrow.tl`, with no behavior difference. The repo already uses this
same split for tests: `cosmic/teal_closure_test.tl`,
`teal_narrowing_test.tl`, `teal_nilflow_test.tl`,
`teal_integer_strict_test.tl`, `teal_metatable_test.tl`,
`teal_config_test.tl` are all already-split siblings of
`cosmic/teal_test.tl` covering different areas of the same checker
surface — a new sibling file is precedented, not an improvised
workaround.

## Change

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

## Non-goals

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
