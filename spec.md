## Evidence

Correction, 2026-09-05: this item originally proposed building a
`create_function` wrapper itself. That would duplicate «Es2a_EOny»
("cosmic.sqlite: expose create_function, create_aggregate and
create_collation"), already filed, already spec'd in depth (the
TEXT/BLOB value-type decision, the determinism flag, files, tests,
example), and already blocked on two other prerequisite items for
reasons specific to that wrapper's own contract. Narrowed here to just
what remains once that wrapper exists: registering `ksuid()` through
it. No new evidence needed for the wrapper's own existence-gap — see
«Es2a_EOny»'s spec for that.

The concrete payoff stands as before: a schema can generate its own
sortable primary keys at the DB layer (`id TEXT PRIMARY KEY DEFAULT
(ksuid())`, or `SELECT ksuid()` directly) instead of every caller
generating one in Lua and binding it in by hand.

## Change

Blocked on both «jiP8_yJF8» ("cosmic.ksuid") and «Es2a_EOny» (the
`create_function` wrapper) landing.

1. Register `ksuid()` (zero-arg, calls `cosmic.ksuid.new()`) through
   `Es2a_EOny`'s `create_function` wrapper, wherever it lands (its own
   spec names `cosmic/sqlite/init.tl` or a new `cosmic/sqlite/udf.tl`).
2. Decide, following that wrapper's own determinism option, whether
   `ksuid()` is registered deterministic or volatile — it is NOT
   deterministic in the SQL sense (two calls return different values),
   so it must be registered volatile; get this wrong and the wrapper's
   own documented warning applies (usable in an index on an expression
   with silently wrong results).
3. Tests: an in-memory db, `SELECT ksuid()` (and a row inserted with a
   `DEFAULT (ksuid())` column), asserting the result satisfies
   `cosmic.ksuid.is_id`, and a case confirming two calls in the same
   statement return different values (the volatile registration is
   doing its job).
4. `cosmic --docs`: document `ksuid()` alongside `cosmic.sqlite`'s
   existing UDF examples once `Es2a_EOny`'s own example lands.

## Non-goals

Any part of the `create_function`/`create_aggregate`/`create_collation`
wrapper itself — that is «Es2a_EOny» in full; `cosmo.ksuid`'s C fast
path (a separate item, blocked on «jiP8_yJF8», not on this one).
