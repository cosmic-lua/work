Decision (from the capture's two options): make the messages
reachable at the sentinel — the better-reading choice — rather than
deleting them. Cosmic-only: the C path discards its own refusal,
message and offset both, and re-reads with the Teal lexer
(cosmic/literal.tl parse()), so refusal messages are Teal-only
surface and the refusal INPUT set does not move.

In `parse_table` (cosmic/literal.tl):
- loop head: a sentinel token refuses `unterminated table in <noun>`
  with its line — reachable by `return {` and, via the separator
  change below, `return {a = 1`;
- value position: the dead `if not v` guard becomes a sentinel check
  refusing `unexpected end of <noun>` with its line — reachable by
  `return {a =`;
- separator position: a sentinel is left for the loop head instead of
  being reported as `found '$EOF$' after a value`; the `not sep` arm
  and the `"<eof>"` fallback go (the sentinel means sep is never
  nil);
- the loop's fall-through `unterminated table` return STAYS, as a
  stated-invariant safety net with a comment saying so. [Corrected at
  review 2026-08-27: the original bullet said it goes; deleting it
  would make a broken sentinel invariant degrade to a silent
  `nil, nil`, which the checker cannot flag and the never-discard-
  errors rule forbids. The reachable-refusal goal is untouched.]

Tests asserting the old `$EOF$` spellings update to the new
messages; `literal_engine_test.tl`'s byte-for-byte engine agreement
holds by construction (both engines report the Teal message).
