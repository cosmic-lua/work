1. **`cosmic/deep.tl`** — two signatures, in the function and in the
   `DeepModule` record (`:120-124`), with the `@param`/`@return`
   comments updated to match:

   - `local function copy<T>(value: T): T`, returning
     `copy_impl(value, {}) as T` with the trailing reason
     `-- cast: copy_impl is the dynamic walk under the generic`.
   - `local function merge<T>(base: T, override: T): T`, returning
     `merge_impl(base as {any: any}, override as {any: any}) as T` with
     `-- cast: records are inspected as maps by the dynamic walk` on the
     line above (the line will not fit the reason at 90 columns).

   That is two cast-carrying lines in the file and no other change:
   `copy_impl`, `eq_impl` and `merge_impl` keep their `any`/`{any: any}`
   parameters, and `equal` is untouched (it returns `boolean` and costs
   its callers no cast).

2. **`cosmic/deep_test.tl`** — declare the fixture records at file
   scope, after the `require`, and give every fixture local its record
   type instead of `{string: any}`/`{any: any}`. The shapes the existing
   tests need: `Nested` (`b: any` — `test_copy_is_independent` overwrites
   `b` with a string on purpose, so the field is honestly `any`);
   `CopyFixture` (`a: integer`, `nested: Nested`, `self: CopyFixture`,
   `x: {integer}`, `y: {integer}`, `name: string` — the union of what
   the four copy tests build); `Limits` (`mem: integer`, `cpu: integer`)
   and `Conf` (`limits: Limits`) for the merge tests. Then delete all 8
   casts: `deep.copy(orig)` is the fixture's own type, so
   `copy.nested`, `orig.nested.b`, `merged.limits` and `base.limits`
   all read directly. In `test_copy_preserves_shared_references`,
   `shared` becomes `{integer}` to match the record field. In
   `test_merge_override_wins_on_type_conflict`, bind the two literals to
   `local nested: {string: any}` and `local flat: {string: any}` and
   pass those, per probe fact 5.

3. **`cosmic/deep_example.tl`** — the same move, with the records
   declared INSIDE `Example_merge` and `Example_copy` per probe fact 4:
   `Limits`/`Config` for the merge example, `Settings`/`Prefs` for the
   copy example. Delete all 5 casts; `config.limits.mem`,
   `config.limits.cpu`, `copy.settings` and `original.settings.theme`
   read directly. The `-- Output:` blocks do not change.

Then rewrite the ratchet floor with exactly the command the gate prints —
`bin/cosmic --make run _build/casts.tl --baseline` — and commit the
result. Never hand-edit `_build/casts_baseline.tl`.
