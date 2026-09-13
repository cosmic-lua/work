Three files. Measured at `489bba2f`: `wc -l cosmic/literal.tl
cosmic/literal_test.tl _fuzz/literal_fuzz_test.tl` is 441, 421, 459 —
59, 79 and 41 lines of headroom under the 500-line cap, and the fuzz
file only shrinks here.

1. **`cosmic/literal.tl:108`** — pass base 10, so the escape is read as
   the decimal the Lua manual specifies and `%q` writes:
   `local n = tonumber(digits, 10) as integer`. One argument; the
   trailing cast justification stays as it is.

2. **`cosmic/literal_test.tl`** — two tests, each called on the line
   after its `end`, per the repo's test convention:
   - `test_every_byte_round_trips_before_a_digit`: for `b = 0, 255`,
     round-trip `{x = string.char(b) .. "0"}` through
     `literal.format`/`literal.parse` and assert equality, collecting
     the failing bytes so a regression names them. This is the loop
     that found the range, kept so a future base-less `tonumber`
     cannot pass. Byte 27 goes through the default `"pin"` layout
     here, which the `\e` defect (3IKgKs34) does not reach, so no byte
     needs excluding.
   - `test_decimal_escape_agrees_with_load`: assert
     `literal.parse('return {x = "\\011"}').x` is byte 11, the same
     byte `load('return "\011"')()` returns.

3. **`_fuzz/literal_fuzz_test.tl`** — retire domain bound 4, which
   exists only for this defect:
   - delete the numbered entry (the `-- 4.` block, lines 57-64 at
     `489bba2f`) and renumber the byte-27 entry from `5.` to `4.`;
   - change the comment's opening count (line 33) from "Five domain
     bounds ... Two of them (4 and 5) are known defects" to four
     bounds, one of them (4) a known defect, keeping the rest of that
     sentence's shape;
   - update the cross-reference in the `ESCAPE_TRAP` doc comment (line
     100) from "domain bound 5 above" to "domain bound 4 above";
   - delete `OCTAL_TRAP_LO`/`OCTAL_TRAP_HI` and their doc comment
     (lines 121-124);
   - in `random_string`, delete the `prev` variable, the `b` local and
     the substitution guard, so the loop is `out[i] =
     random_char(src)`; rewrite its doc comment's first sentence to
     "Draw a string of alphabet characters." and drop the sentence
     about the fixed-byte substitute, which no longer describes it.

   Bound 5 (byte 27, item 3IKgKs34) lives in `random_char` and is
   independent — it stays.
