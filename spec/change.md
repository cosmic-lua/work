One shape per file; each was applied and passed
`o/bin/cosmic --check types <file>` during refinement.

1. **`cosmic/check.tl`** (`deep_equal`): replace the
   `type(a) ~= "table" or type(b) ~= "table"` early return with
   `if not (a is {any: any}) or not (b is {any: any}) then return
   false end`; delete the `ta`/`tb` cast lines and use `a`/`b`
   directly in both `pairs` loops.
2. **`cosmic/fetch/headers.tl`** (`normalize`): replace the
   `value is table` branch with `value is {string}` (drops the `:25`
   cast; `ipairs(value)` is then typed), and split the else into
   `elseif value is string then table.insert(list, value)` with a
   final `else table.insert(list, tostring(value)) end`. The decision,
   stated: the binding contract is string-or-{string} (the module
   header says so); a value that is neither is a contract violation,
   and `tostring` keeps the declared `{string}` list true at runtime
   while producing the same joined output the old blind cast did for
   e.g. numbers.
3. **`cosmic/fs/types.tl`** (`extend_metatable`): keep the
   `type(mt) ~= "table"` guard and the `mt as {string: any}` cast, but
   change its reason to the measured one — a comment line above:
   `-- cast: metatable<any> is a nominal the checker refuses
   is-dispatch on`. Then `local idx = (mt as ...).__index`, replace
   the `type(idx) ~= "table"` guard + `methods` cast with
   `if not (idx is {string: any}) then return false end` and write
   through `idx` directly.
4. **`cosmic/quicksand/proxy/rules.tl`** (`validate_rule`): change the
   guard to `if not (rule is {string: any}) then ... end` (same
   runtime check — `is {K: V}` compiles to `type(x) == "table"`), then
   `local r = rule` with no cast.
5. **`cosmic/sandbox/init_test.tl`**: give `find_rule` its real
   signature — `(rules: {landlock.Rule}, path: string):
   landlock.Rule` (the module already requires
   `cosmic.sandbox.landlock` at line 4; `plan.for_landlock` returns
   `RestrictOptions` whose `rules` is `{Rule}`), drop the `rr` cast,
   and drop the `:177` `r.access as integer` cast — `r.access` is a
   plain `integer` read.

During refinement the full diff also passed
`o/bin/cosmic --make test cosmic/check_test.tl cosmic/fetch/headers_test.tl`
(`test: PASS (2 files)`).

**The casts ratchet fires on this diff** (five files land under their
committed baseline). Run exactly the regen its failure message prints —
`bin/cosmic --make run _build/casts.tl --baseline` — and commit the
regenerated `_build/casts_baseline.tl` with the change; in scope, and
the only gate-touching edit allowed.
