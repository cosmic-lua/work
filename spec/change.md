Add `cosmic/sqlite/column.tl`, a new internal shard, and export its three
readers from `cosmic/sqlite/init.tl`. Then rewrite the 9 cast sites to call
them.

**1. `cosmic/sqlite/column.tl` (new file).** Declare

```teal
local type Row = {string: any}
```

and three readers over it, each returning the declared type or `nil` plus a
message (the fallible-value shape: two slots, nothing after the error):

| function | signature | accepts |
| --- | --- | --- |
| `text` | `function(row: Row, column: string): string \| nil, string` | `v is string` |
| `number` | `function(row: Row, column: string): number \| nil, string` | `v is number` |
| `integer` | `function(row: Row, column: string): integer \| nil, string` | `v is integer` |

Each reads `local v = row[column]` and narrows with `is` — **no `as` cast
anywhere in this file**. Verified against the tree's pinned tl on 2026-08-25:
`is string`, `is number` and `is integer` all narrow a `{string: any}` element
cast-free, and `is integer` compiles to a `math.type` test, so `3.5` is
rejected at runtime while `7` is accepted.

The three failure messages, exactly:

- `row[column] == nil` → `column "<column>" is absent or NULL`
- `text`, wrong type → `column "<column>" is <type(v)>, want string`
- `number`, wrong type → `column "<column>" is <type(v)>, want number`
- `integer`, wrong type → `column "<column>" is <desc>, want integer`, where
  `desc` is `a float` when `type(v) == "number"` and `type(v)` otherwise

Give each reader the house doc-comment treatment (`---` summary, `@param`,
`@return` per return slot). The module returns a record-typed table
(`local M: ColumnModule = {text = text, number = number, integer = integer}`)
in the same shape as `cosmic/sqlite/bind.tl`.

**2. `cosmic/sqlite/init.tl`.** `require` the new shard, add
`column_text`, `column_number` and `column_integer` to the `record sqlite`
interface and to the `M` table literal, forwarding to the shard's `text`,
`number` and `integer`. The names carry the `column_` prefix because
`sqlite.blob` is already the BLOB *constructor* — a bare `sqlite.blob` reader
would collide with it. Do **not** add a `Row` type alias to the `sqlite`
record; the row type stays spelled `{string: any}` on the public surface.

Measured now: `wc -l < cosmic/sqlite/init.tl` is 453, so 47 lines of headroom
under the 500-line cap; this adds roughly 12.

The doc page needs no separate edit: `_tool/doc/index.tl`'s `flatten_shards`
folds a shard's function docs onto the parent page, filtered by the parent's
own export list — which is exactly how `sqlite.blob` (defined in
`cosmic/sqlite/bind.tl`) already renders under `### blob` in
`bin/cosmic --docs sqlite`. Exporting from `init.tl` is what publishes them.

**3. `cosmic/sqlite/column_test.tl` (new file).** Cover all three readers:
the happy path per type, the absent-column message, the wrong-type message,
and `integer` rejecting a float. Follow the house test form — one `test_*`
function called on the line after its `end`.

**4. The 9 cast sites.** Replace each `row.<col> as string` with
`check.must(sqlite.column_text(row, "<col>"))` and each
`(row.<col> as number)` with `check.must(sqlite.column_number(row, "<col>"))`,
deleting the now-unneeded `-- cast: from any` comment on each line. All three
files already `require` both `cosmic.check` and `cosmic.sqlite`. Measured
2026-08-25 against `dbca9e77` with
`git ls-files '*.tl' | xargs grep -n -- "-- cast: .*from any"`:

| file | lines | reader |
| --- | --- | --- |
| `cosmic/sqlite/advanced_test.tl` | 434, 456 | `column_text` (456 has two casts on one line) |
| `cosmic/sqlite/close_test.tl` | 129 | `column_text` |
| `cosmic/sqlite/init_test.tl` | 176, 194, 431 | `column_text` (431 has two casts on one line) |
| `cosmic/sqlite/init_test.tl` | 101, 228, 403 | `column_number` |

`cosmic/sqlite/init_test.tl` is 491 lines — **9 lines of headroom** — so the
rewrite must stay effectively line-neutral: each site drops its `-- cast:`
comment line and may spend that line on a wrap. `advanced_test.tl` is 476
(24 lines of headroom). Both bounds are Acceptance commands below.

**5. `_build/casts_baseline.tl`.** The closure lowers three rows. Run exactly
the regen command the gate's failure message prints
(`bin/cosmic --make run _build/casts.tl --baseline`) and commit the result;
same for the coverage floor if `--make ci` asks for it. Read the regenerated
diff before committing: only the rows this change touches may move — a
*lowered* row anywhere else means the regen ran against a partial tree, so
re-run it, never commit it.
