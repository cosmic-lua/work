Carry the strict mode as a NEW patch group in `3p/tl/tl_patch.tl`,
beside the two that exist today. Re-measured 2026-08-26: the file's
header comment says "Two groups of edits" and the groups are
`ast-cache-*` (5 entries) and `narrow-*` (14 entries);
`grep -c 'note =' 3p/tl/tl_patch.tl` reports 19 and
`wc -l 3p/tl/tl_patch.tl` reports 499. Name the new group `strictnil-*`
and extend that header comment to describe three groups, the way the
narrow-* paragraph describes its own.

The census's `## Method` names the two hinges and the exact prototype
that closed them:

1. `subtype_relations["union"]["*"]` and `["union"]["nominal"]` reject a
   nil-carrying union against a sink that does not admit nil. Leave
   `subtype_relations["nil"]["*"] = compare_true` alone, so bare `nil`
   stays a subtype of everything and `local x: string = nil` and every
   `x == nil` comparison keep working — the prototype confirmed that
   flipping THAT relation instead produces false positives on every
   equality guard in the tree.
2. The binary-operator path reports an operand carrying nil before
   `unite()` drops it, for the arithmetic, bitwise, concatenation and
   relational operators. `and`, `or`, `==` and `~=` stay excluded: they
   are how a nil is disposed of, not a place it leaks to.

Every entry is an ANCHORED edit like the others — each `find` must match
the pinned `tl.lua` exactly once, so a pin bump fails the fetch loudly
rather than silently dropping the mode.

Then: flip `cosmic/teal_narrowing_test.tl`'s
`test_nil_union_is_admitted_outside_an_index` to its opposite — the
boundary moves, so the test that pins it moves with it, in this slice
and no other — and collect the doctrine dividend the census priced.

Also add a new, upgrade-shaped case to the same file, distinct from the
index-shaped flip above: a function retyped from `T` to `T | nil,
string` (mirroring `string.shell_quote`'s real retyping in the
experiment that sized this slice), used both in a concatenation and as
the initializer of a `local x: T` — both refused with `STRICTNIL` at
the two sites. This is new coverage, not a moved boundary: it is the
consumer-side case the binary-operator hinge above exists to close,
and the one the upgrade experiment found totally silent under today's
checker (`55xy_ILjS`).

Both of the doc passages below are re-measured 2026-08-26:

- `AGENTS.md:187-190`, the "And what the checker never DEMANDS: an
  unnarrowed `T | nil` passes into a non-nil parameter, a declared
  non-nil local, arithmetic and concatenation — only an index refuses
  it, so an unguarded union becomes a runtime nil downstream (pinned in
  `cosmic/teal_narrowing_test.tl`)" sentence, deleted outright.
  (`grep -n 'never DEMANDS' AGENTS.md` reports line 187; `AGENTS.md` is
  468 lines.)
- `docs/guides/checking.md:224-265`, `### Where Narrowing Is Required`,
  rewritten to one sentence: a guard is required wherever a union
  reaches a non-union sink. Its current 20-line snippet's stated point
  is that it "compiles at full strictness", which stops being true here,
  so the snippet goes with it. (`grep -n '### Where Narrowing Is
  Required' docs/guides/checking.md` reports line 224; the section runs
  to the `### Record Types` heading; the file is 406 lines.)

Whether this ALSO goes to teal-language/tl: the census recommends not.
It rejects programs that compile today, so it is a mode or a fork's
policy, and proposing it beside the four strictly-better narrowing
rules would sink both.
