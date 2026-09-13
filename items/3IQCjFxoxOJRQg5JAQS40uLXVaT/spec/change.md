Five files.

**1. `_types/gentl.tl`** — three edits, +7 lines (303 → 310):

- `NAMED` (`:26`) gains `Comment = true`, so `erase("{Comment}")`
  returns `"{Comment}"` instead of `"{any}"`.
- `RECORD_FIELDS` (`:180`) gains `Comment = {"x", "y", "text"}`, placed
  alphabetically before its `Token` entry. That is what puts `Comment`
  through `verify_record` (`:134`) on every build, so tl dropping or
  renaming a field fails the build rather than silently widening the
  type.
- `PRELUDE` (`:191`) gains a `record Comment` block with those three
  fields, immediately above `record Token`, and `Token`'s `comments`
  field changes from `{any}` to `{Comment}`.

**2. `cosmic/format/init.tl`** — `build_items`' inner loop loses its
cast line and reads the fields directly, 9 lines becoming 8:

```teal
      for _, c in ipairs(token.comments) do
        items[#items + 1] = {
          y = c.y,
          x = c.x,
          tk = c.text,
          kind = "comment",
        }
      end
```

Nothing else in the file moves.

**3. `_types/gentl_test.tl`** — one line in `test_erasure_rules`'
`cases` table, beside the existing `["{Token}"] = "{Token}"`:

```teal
    ["{Comment}"] = "{Comment}",
```

This is the only thing that pins `Comment`'s membership in `NAMED`;
without it, a future edit that drops the entry silently erases the
record back to `any` and the formatter's casts come back.

**4. `_types/tl_conformance_test.tl`** — one line after
`local _lex_errs: {tl.Error} = lex_errs`:

```teal
local _comments: {tl.Comment} = tokens[1].comments
```

Type-only, like every other line in that file: it fails to compile if
`Comment` stops being reachable as `tl.Comment` or `Token.comments`
stops carrying it.

**5. `_build/casts_baseline.tl`** — `["cosmic/format/init.tl"]` goes
from `9` to `5`. Run exactly the regen command the gate prints and
commit its output; no other row moves.
