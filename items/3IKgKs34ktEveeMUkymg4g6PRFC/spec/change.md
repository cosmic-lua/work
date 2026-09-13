Three files.

**1. `cosmic/_literal_format.tl`** — refuse byte 27 in a string the
compact writer would spell.

- Add one file-local predicate beside the existing guards, in their
  style, testing a string for the byte the C encoder spells its own
  way: a `find` for `"\27"` with `, 1, true` (the `find-needle` lint
  requires the plain-substring flag). Give it the doc comment shape
  its neighbours have, naming WHY — `cosmo.EncodeLua` writes byte 27
  as `\e`, a fork extension `literal.parse`'s `ESCAPES` does not
  admit, so a string holding it is written by the pin layout instead.
- Call it from `is_compact_scalar`'s `v is string` branch
  (`:67-69`), which today returns `true` unconditionally.
- Call it on the KEY in `is_compact_writable`'s loop, beside the
  existing `RESERVED[k]` test (`:331-333`).

Do not change `format`, the pin layout, `MAX_DEPTH`, `RESERVED`, or
any refusal message. The handoff at `:379` already routes a refused
value to the pin layout and needs no edit.

**2. `cosmic/_literal_format_test.tl`** (+~30 lines) — one
`test_every_byte_round_trips` in the file's established shape, called
on the line after its `end`. For each of the 256 byte values, in both
layouts (`pin` and `compact`), as a value (`{x = string.char(b)}`) and
as a key (`{[string.char(b)] = 1}`): format, parse the result back,
and assert the parsed value equals what went in. On failure the
assertion message names the byte, the layout and the position, so the
next byte an encoder spells its own way is reported by name rather
than as a generic mismatch. This is the loop from Evidence, kept.

**3. `_fuzz/literal_fuzz_test.tl`** — remove the bound this defect
forced, in the same PR:

- delete `ESCAPE_TRAP` and `ESCAPE_TRAP_SUBSTITUTE` (`:93-94`) and
  the substitution branch that reads them (`:104-105`), so byte 27 is
  drawn like every other byte;
- delete entry 4 from the domain-bounds comment (`:56-62`) and change
  its opening line (`:33`) from "Four domain bounds" to "Three", so
  the count matches the list.
