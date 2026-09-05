## Evidence

The C layer already supports this: `tool/net/lsqlite3.c:1378`
(`db_create_function`) is registered in `dblib` at line 2270, so
`cosmo.lsqlite3`'s raw `db:create_function(...)` already exists. But
`cosmic/sqlite/*.tl` (`init.tl`, `bind.tl`, `column.tl`, `extras.tl`,
`defaults.tl`, ...) wraps none of it — `grep -rn create_function
cosmic/sqlite*.tl cosmic/sqlite/*.tl` is empty (confirmed 2026-09-05;
independently found the same gap researching cosmic-lua/work's own
board item «BZCt_Z5l7» on 2026-09-04, which needed a scalar function
for an unrelated reason and found nothing to call). So this is purely a
`cosmic-lua/cosmic`-side wrapping task once «jiP8_yJF8» ("cosmic.ksuid")
exists — no new cosmopolitan work, and independent of «cosmo.ksuid»'s
C fast path (this works against whichever `cosmic.ksuid` implementation
is live at build time).

The concrete payoff: a schema can generate its own sortable primary keys
at the DB layer (`id TEXT PRIMARY KEY DEFAULT (ksuid())`, or `SELECT
ksuid()` directly) instead of every caller generating one in Lua and
binding it in by hand.

## Change

Blocked until «jiP8_yJF8» lands.

1. `cosmic/sqlite/extras.tl` (or wherever fits under the file's line
   cap): a typed wrapper over `db:create_function`, scoped to what a
   scalar SQL function needs — a name, an arg count, and a Lua function
   returning one value. General capability, proven by one real
   registered function rather than built speculative-general up front.
2. Register `ksuid()` (zero-arg, calls `cosmic.ksuid.new()`) through
   that wrapper as its first real consumer.
3. Tests: an in-memory db, `SELECT ksuid()` (and a row inserted with a
   `DEFAULT (ksuid())` column, if the wrapper's placement supports
   registering before table creation), asserting the result satisfies
   `cosmic.ksuid.is_id`.
4. `cosmic --docs`: document the new wrapper function alongside
   `cosmic.sqlite`'s existing reference.

## Non-goals

A general-purpose arbitrary-arity or aggregate/window custom-function
API — this ships exactly what `ksuid()` needs, and a second real
consumer earns the next increment of generality, not this item;
`cosmo.ksuid`'s C fast path (a separate item, also blocked on
«jiP8_yJF8», not on this one).
