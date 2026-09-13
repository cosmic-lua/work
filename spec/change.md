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
