## Evidence

Board item `3Int8VXj9GcPOKsNsQtTiP5t8cl` («TiP5_t8cl», "cosmic.sqlite: wrap
BLOB values in a distinct type using the new value_type/column_type
accessors") specifies, in its `## Change`:

> `cosmic/sqlite/bind.tl`: on the UDF-argument side, the equivalent wrap
> using `value_type(n)`.

and, in its `## Non-goals`:

> No UDF-registration changes beyond wrapping argument values that already
> flow through the existing UDF-arg push path.

Both presuppose `cosmic.sqlite` already exposes a UDF registration surface
(a wrapped `db:create_function`/`create_aggregate`) with an existing
argument push path in `bind.tl` that only needs a `value_type` check added.
A builder session (2026-09-05) that pulled the item to build found no such
surface anywhere in the tree, measured:

    $ grep -rln "create_function\|create_aggregate" --include="*.tl" --include="*.md" . | grep -v '^./o/'
    (no output)
    $ git log --all --oneline | grep -i "udf\|create_function\|create_aggregate"
    (no output)

`cosmic/sqlite/init.tl`'s `Database` record is a closed, hand-populated
method set (`prepare/query/query_one/exec/exec_script/transaction/
savepoint/last_insert_rowid/changes/close`) with no `__index` fallback to
the raw `lsqlite3.Database` and no field exposing it, so a caller has no
way to reach `create_function`/`create_aggregate` through `cosmic.sqlite`
at all today, and no `bind.tl` code receives or pushes a UDF's `ctx, ...`
arguments. The pinned cosmopolitan release (`2026.09.04-65bc139fc`) does
carry the accessors the item needs (`lsqlite3.Context:value_type`,
`lsqlite3.Statement:column_type`, confirmed against
`o/_types/types_gen/cosmo/lsqlite3.d.tl` and `/zip/.lua/definitions.lua`
after `bin/cosmic --make build`), so the blocker is scoped to the
UDF-argument bullet only — the read-side (`column_type`) half of the
Change is otherwise buildable.

Separately, the same builder found the read-side bullet's named file is
also too narrow: "`cosmic/sqlite/column.tl`: on a column read, check the
new `column_type(n)` accessor" — but `column.tl` only ever receives an
already-materialized `Row` (`{string: any}`) built by
`cosmic/sqlite/row_iter.tl:81` (`row[...] = raw_stmt:get_value(idx)`),
which is where the raw statement and column index actually live. Wiring
the wrap through requires touching `row_iter.tl` too, a file the Change
does not name.

## Change

Decide, then respec `3Int8VXj`'s `## Change` accordingly:

1. Either (a) scope this item's UDF-argument bullet out entirely — ship
   only the `column_type`-based read-side wrap and the `bind_at`
   round-trip dispatch on the existing write-side `Blob`/`blob()` marker
   (already present, `cosmic/sqlite/bind.tl`, re-exported at
   `cosmic/sqlite/init.tl:427,439,453`) — and open a separate, later item
   for UDF registration support if `cosmic.sqlite` is meant to gain one; or
   (b) fold "add a UDF registration surface to `cosmic.sqlite`" into this
   item's own scope, superseding its current Non-goal.
2. Whichever is chosen, name `cosmic/sqlite/row_iter.tl` explicitly
   alongside `column.tl` in the respec'd Change, since that is where the
   raw statement/index needed for the `column_type(n)` check actually live.

## Non-goals

Deciding the UDF registration surface's own shape (its argument-push
mechanics, its record shape) if (b) above is chosen — that becomes its own
spec once the scope decision is made.
