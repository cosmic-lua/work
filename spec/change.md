1. **`cosmic/quicksand/box/merge.tl`** — declare
   `merge(...: types.BoxOptions): types.BoxOptions`, in the function
   and in `BoxMergeModule` (`:128`), and update the `@param`/`@return`
   comments. Keep `merge_section`, `concat_unique`, `merge_map` and
   `schema` walking `{string: any}` — the walk is schema-driven and
   dynamic on purpose, as the module's own header says of unknown keys.
   Bridge the two with the boundary casts fact (1)-(3) force:

   - in `merge`'s loop, cast each `select(i, ...)` policy to
     `{string: any}` with `-- cast: record inspected as map`;
   - cast the accumulated result back with
     `-- cast: dynamic walk rebuilt as the record it walked`.

   That is two `as` tokens in the file, both honestly reasoned.

   Then close the four internal `from any` casts with fact (4), and
   widen the two helpers to admit the nil their bodies already handle
   (`concat_unique` and `merge_map` both open with `if a then`):

   - `concat_unique(a: {any} | nil, b: {any} | nil)`, called
     `concat_unique(av is {any} and av or nil, bv is {any} and bv or nil)`
   - `merge_map` likewise over `{any: any} | nil`
   - `:100-101` become `av is {string: any} and av or {}` and the same
     for `bv`; the `elseif type(av) == "table" or type(bv) == "table"`
     guard above them is the same test `is` compiles to, so nothing
     changes at runtime.

2. **`cosmic/quicksand/box/init.tl`** — delete the `as BoxOptions` at
   `:186`; `box_merge.merge(...)` now returns `BoxOptions`.

3. **`cosmic/quicksand/box/merge_test.tl`** — delete all 14 casts. Every
   `(out.fs as {string: any}).ro as {string}` becomes `out.fs.ro`, and
   the same for `out.net`, `out.env`, `out.proc`, `out.sys`. Where a
   test reads a MAP field (`net.allow`, `env.set`), the record declares
   it, so the read is typed too. Model the result on
   `cosmic/sandbox/init_test.tl:259-272`.

4. **`cosmic/quicksand/box/init_test.tl`** — delete `:120` and `:122`;
   `:119` (`record inspected as map`) goes with them, since `out` is now
   a `BoxOptions` and `out.fs.ro` reads directly. The file's floor row
   drops 3 → 0.

`cosmic/quicksand/init.tl:45` already declares
`merge: function(...: BoxOptions): BoxOptions` and needs no change —
confirm it still type-checks rather than editing it.

Then rewrite the ratchet floor with exactly the command the gate
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and
commit the result. Never hand-edit `_build/casts_baseline.tl`.
