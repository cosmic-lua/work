Four files.

**1. `3p/cosmos/cosmos_pin.tl`** — `version` to
`2026.08.24-354c17e08` and the `*` platform `sha` to
`eae5513bc5283b684e51e6524080985505836f76c5a398f0c8c5ee68cedde380`
(both measured above). Nothing else in the file moves.

**2. `cosmic/literal.tl`** (+~35 lines; 441 today, 59 under the cap,
so the file stays under 490 — an Acceptance bound below) —

- bind the C entry point once at module scope, beside the existing
  `cosmo` require: `local decode_lua = cosmo.DecodeLua`, with a doc
  comment saying it may be nil under an older cosmos and what happens
  then;
- add `engine: string` to the `Options` record, documented in the
  record's own comment style as `"auto"` (default), `"teal"`, `"c"`,
  and add it to `parse`'s `@param` line beside `file`, `noun` and
  `on_duplicate`;
- in `parse`, before the lexer runs: choose the C reader when
  `engine` is `"auto"` and `decode_lua` is non-nil and `on_duplicate`
  is nil, or when `engine` is `"c"`; choose the Teal reader
  otherwise. `engine = "c"` with `decode_lua` nil returns
  `nil, "<file>: the C literal reader is not in this build"` — a
  refusal, never a silent fallback, because a caller that pinned an
  implementation asked to know. `engine` set to anything but those
  three strings returns a refusal naming the three, in the shape
  `format`'s layout refusal already uses
  (`cosmic/_literal_format.tl`'s `a layout is "pin" or "compact",
  not "..."`);
- the C path calls `decode_lua(source)`; on a table it returns it; on
  a refusal it DISCARDS the C message and offset and returns the
  result of the Teal reader on the same source, which is where the
  message comes from (question 2).

**3. `cosmic/literal_engine_test.tl`** (new, ≤ 120 lines) — the
dispatch's own tests, in a new file rather than in
`cosmic/literal_test.tl`, which is 453 lines and has no room. Each
`test_*` called on the line after its `end`. Cover:
`engine = "c"` and `engine = "teal"` return equal values for a nested
payload; a refusal under `"c"` has the same message, byte for byte, as
the same refusal under `"teal"` (a non-literal expression, a repeated
key, junk after the table, a missing `return`), including the `<file>:`
prefix a `file` option sets; `on_duplicate` still resolves a repeat
under `"auto"`; an unknown `engine` string is refused and the message
names the three.

**4. `_fuzz/literal_fuzz_test.tl`** — one new property,
`differential`, in the file's established property shape: every
generated source is parsed by BOTH engines and the two results
compared — value against value with the file's existing deep
comparison, refusal against refusal by message equality. Do not widen
the alphabet, the iteration count, or the generators.

The PR description carries the scouting numbers from question 5,
labelled as scouting: the wall time of 10,000 `literal.parse` calls
over the text of `3p/cosmos/cosmos_pin.tl` under `engine = "teal"` and
under `engine = "c"`, timed with `cosmic.time` through `bin/cosmic
--make run`, best of five runs each, with the script inlined in the
description so the number can be re-taken.
