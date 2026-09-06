## Evidence

Independently of the `tl.generate` bug filed alongside this item,
cosmic's own formatter (`cosmic/format/rules.tl`, which reassembles
text from `tl.lex`'s TOKEN stream — it never calls `tl.generate`) has
the identical bug in its own, separate implementation:

    $ cat dblminus.tl
    local z = - -1
    print(z)

    $ bin/cosmic --format dblminus.tl
    local z = --1
    print(z)

    $ bin/cosmic --format dblminus.tl > out.tl && bin/cosmic out.tl
    nil

`needs_space` (`cosmic/format/rules.tl:167-232`) has this block:

    223   if prev.tk == "-" and prev.kind == "op" then
    224     if prev_prev == nil then
    225       return false
    226     end
    227     if unary_minus_after[prev_prev.tk] or (prev_prev.kind == "keyword" and unary_minus_after_kw[prev_prev.tk]) then
    228       return false
    229     end
    230   end
    231   return true

This suppresses the space after a unary `-` (correct: `-1` not `- 1`),
but never checks whether `cur` (the NEXT token) is itself `-`. Two
adjacent unary minuses collapse with no space, and the result re-lexes
as a `--` line comment, silently changing `local z = - -1` (`z == 1`)
into `local z = --1` (`z == nil`). `cosmic/format/regressions_test.tl`
has tests for single unary minus (`test_bug5_unary_minus_no_space`)
and binary minus (`test_bug5_binary_minus_gets_space`) but no case for
two consecutive unary minuses — this shape has no test today.

## Change

In `needs_space` (`cosmic/format/rules.tl:223-231`), add a check: when
`cur.tk == "-"` as well as `prev.tk == "-"`, always return `true`
(keep the space) regardless of what `prev_prev` is — two adjacent `-`
tokens must never touch, independent of whether the first is unary or
binary, because concatenating them always re-lexes as a comment.

## Acceptance

Add to `cosmic/format/regressions_test.tl`, beside the existing
`test_bug5_*` cases: format `"local z = - -1\nprint(z)\n"` and assert
the output is unchanged (still two separate `-` tokens with a space
between); also cover three consecutive (`- - -1`) since the same
adjacency check must not special-case exactly two. A second assertion
loads the formatted output via `load()` (or `cosmic.teal`) and checks
it evaluates to `1`, not `nil` — the round-trip, not just the text
shape, since the text shape is the whole bug.
