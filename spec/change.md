One new file, `_fuzz/literal_fuzz_test.tl`, in the shape of
`_fuzz/json_fuzz_test.tl` (module doc comment with an `--- env:
FUZZ_SEED FUZZ_ITERS` line, generators as `source.Recorder` draws,
each property registered on `_fuzz.driver`). Nothing else moves.

A value generator drawing the grammar's domain: nested `{string: any}`
tables to a bounded depth, with string, boolean, integer and finite
float values, and string keys and values drawn from an alphabet that
includes the bytes that make an encoder and a parser disagree —
quotes, backslash, newline, tab, `\0`, a byte above 0x7f, and the
brace/bracket/comment punctuation of the grammar itself.

Four properties:

1. **totality** — `literal.parse(s)` on arbitrary bytes (up to a
   bounded length) answers: a table or `nil, string`, never a throw
   and never a hang. This is the module's founding promise stated as a
   property.
2. **round trip** — for a generated value `v`, `literal.parse(
   literal.format(v))` deep-equals `v` (`cosmic.deep`, as
   `json_fuzz_test.tl` uses it).
3. **refusal is total too** — `literal.format` on a generated value
   from a WIDENED domain (one that also draws functions, cycles,
   non-string keys, NaN and the infinities) either returns source that
   `parse` reads back as the value, or refuses with a string; it never
   throws and never returns source `parse` then rejects. This is the
   property that catches a writer emitting what its own reader cannot
   read.
4. **mutation** — take a valid formatted source, mutate one byte or
   splice a fragment, and `parse` still answers. Same shape as the
   json properties' corrupted-encoding case.

State every domain bound in a comment block, saying for each whether
it is a real contract (the grammar refuses it) or a known defect with
its board item — the pattern `json_fuzz_test.tl` sets at its own
bounds comment. Board item `3ICDKhO3` (a flat table at depth 33
renders inline past the cap `parse` refuses) is a known round-trip
break: bound the generator's depth below it and name the item in the
comment, rather than generating a failure that is already filed.
