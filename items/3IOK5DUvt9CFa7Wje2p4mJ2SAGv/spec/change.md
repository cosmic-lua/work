**1. `_cli/lint.tl` — export `cast_lines`.** The function already exists
at line 35 and is unchanged; only the module surface grows. Add to
`LintModule`, immediately before `check_cast_justification`:

```teal
  cast_lines: function(content: string, file: string): {integer}
```

and to the `M` table in the same position:

```teal
  cast_lines = cast_lines,
```

Measured: `wc -l < _cli/lint.tl` is 455, so 43 lines of headroom remain
under the 500-line cap after these two.

**2. `_build/casts.tl` — count `as` tokens, via the linter's scanner.**
Add `local lint = require("_cli.lint")` to the import block (alphabetical:
after `floor`, before `fs`). Delete `in_text` (lines 39–56, the doc
comment and the function) and replace the per-file body inside `count`

```teal
            local text = fs.read(path)
            local n = text and in_text(text) or 0
```

with

```teal
            local text = fs.read(path)
            local n = text and #lint.cast_lines(text, path) or 0
```

`cast_lines` returns each line at most once, so this is still a count of
cast LINES, which is what the floor's per-file numbers have always meant.
A file `tl.lex` cannot lex yields `{}`, i.e. 0 — the same treatment
`fs.read` failing already gets, and the same the linter gives.

Rewrite the two places that describe the old mechanism, and nothing else
in the file:
- the module header's third paragraph (lines 4–9): the reason each cast
  line is findable is still that `--make lint` demands a justification,
  but what this module counts is the `as` tokens themselves, through
  `_cli.lint`'s scanner — one lexer, shared with the gate that enforces
  the rule, so a cast quoted in a string or named in a doc comment is not
  counted.
- `count`'s doc comment, which must stop promising that "a quotation
  costs a baseline entry".

Measured: `wc -l < _build/casts.tl` is 157; this nets out shorter.

**3. `cosmic/compress.tl` — delete the two orphaned reasons.** Line 48
(`-- cast: same word set; the binding names its enum independently`, above
`local result, err = cosmo.Deflate(...)`) and line 68 (the identical
comment above `local result, err = cosmo.Inflate(...)`). Neither line
below them holds an `as`; verified 2026-08-25 by
`grep -n " as " cosmic/compress.tl`, which prints only prose matches
("as used inside ZIP files", "as inside ZIP files", "as nil, err"). Delete
only those two comment lines — the line above line 68
(`-- The binding reports truncated or corrupt input as nil, err.`) is a
real comment and stays.

**4. `_build/casts_test.tl` — reword the fixture test and add the case
that proves the fix.** Rename
`test_count_reads_justification_comments` to
`test_count_reads_as_tokens_not_their_justifications`, updating its
call line and its comment above. The existing `both.tl` fixture keeps
asserting 2 (both of its lines carry a real `as`; only the reason for the
number changes). Add one more fixture file, `cosmic/quoted.tl`, written
beside `both.tl` and `none.tl`:

```teal
  local quoted = table.concat({
      "local s = \"local a = x as {string} -- cast: from any\"",
      "-- cast: a reason with no cast under it",
      "local b = 1",
      "print(s, b)",
    }, "\n") .. "\n"
```

with the assertion

```teal
  assert(got["cosmic/quoted.tl"] == nil,
    "a cast quoted in a string, and a reason with no cast, are not counted")
```

Measured: `wc -l < _build/casts_test.tl` is 93 — 407 lines of headroom.

**5. `_build/casts_baseline.tl` — regenerate.** Run exactly the command
the gate's failure message prints,
`bin/cosmic --make run _build/casts.tl --baseline`, and commit the result.
Read the diff before committing: only the four rows in `Acceptance` may
move. This is a ratchet the change legitimately lowers; re-baseline it
with that command and never weaken the gate any other way. If the
coverage gate also asks on the day, run the command IT prints and commit
that too.
