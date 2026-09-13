**This item writes and lands the checker patch only. It does NOT
delete any of the 5 casts above** — see Non-goals; the cold-build rule
(CLAUDE.md) is why.

1. **Fetch and locate the anchor.** `bin/cosmic --make fetch` unpacks
   the pinned tl source to `o/3p/tl/tl.tl`. Find the checker's guard/is
   narrowing machinery — the same code the existing `narrow-eq-nil`,
   `narrow-truthiness` and `narrow-or-guard` entries in
   `3p/tl/tl_patch/narrow.tl` already touch (read those three for the
   `IsFact`/guard-fact shape tl already tracks per-variable) — and the
   place a guard's fact is keyed, today, by bare variable name.

2. **Write a new `3p/tl/tl_patch/narrow.tl` entry**, in the same
   `find`/`replace`/`note` shape as every entry in that file (worked
   example, `narrow-and-operand`, `3p/tl/tl_patch/narrow.tl:28-32`):

   ```teal
   ["narrow-record-field"] = {
     file = "tl.lua",
     note = "a guard on `x.field` narrows the field's nil union at the use, invalidated by any assignment to `x.field` or to `x`",
     find = [=====[<exact tl.lua snippet, from the fetched o/3p/tl/tl.tl>]=====],
     replace = [=====[<the same snippet plus the cosmic carried-patch comment and the fix>]=====],
   },
   ```

   The fact to add: a guard on `x.field` (`if x.field then`,
   `assert(x.field)`, `x.field == nil`/`~= nil`, the same shapes
   `narrow-truthiness`/`narrow-eq-nil`/`narrow-assert` already cover for
   bare variables) narrows `x.field`'s nil union at reads of `x.field`
   after the guard, within the same scope those entries already narrow
   in. Invalidation: any assignment to `x.field` (or to `x` itself)
   drops the fact, the same rule a bare variable's fact already follows
   — do not narrow across an intervening write. `find` must match the
   pinned `o/3p/tl/tl.tl` EXACTLY once (D21's exactness rule); if it
   does not, the anchor moved or the mechanism needs a different hook —
   report that rather than force a near-match.

3. **Flip the canary.** `cosmic/teal_test.tl:159-179`
   (`test_hint_index_through_nil_union`) currently asserts the un-narrowed
   error. Once the patch narrows `o.sub.x`, rewrite this test to the
   `test_narrowing_canary` shape just above it (line 73): assert
   `result.ok` and that the snippet's `return o.sub.x` typechecks
   clean, with a comment naming this as the record-field-narrowing
   canary (replacing `test_hint_index_through_nil_union`, which no
   longer produces an error to hint about — if a *different* record-field
   nil-union pattern still fails to narrow, keep a trimmed version of
   this test for that residual case instead of deleting it outright).

4. **Land it — no upstream filing required.** Per D21 as amended
   2026-09: reuse branch `3IpBKCCg` (commit `f0234765`) rather than
   redoing the engineering. Its 16 `teal-language/tl#PENDING`
   placeholders in `3p/tl/tl_patch/narrow_record_field.tl`'s `note`
   fields are stale under the old clause — replace each with the plain
   rationale (the fact-and-invalidation sentence in step 2 above, or
   the equivalent local to each of the 16 entries), with no issue
   number required. Filing an issue in `cosmic-lua/cosmic` or
   upstream at `teal-language/tl` is optional, never a precondition;
   do it only if you judge it independently worth doing. Re-run
   `bin/cosmic --make ci` on the updated head, then open the PR
   (`Board: FePr_L4FB`'s full id as the body's first line, per the
   usual convention) and hand it to `take FePr_L4FB --pr N`.

Gate with `bin/cosmic --make ci`, including the flipped canary.
