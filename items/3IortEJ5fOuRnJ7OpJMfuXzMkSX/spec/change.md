- `cosmic/_teal_ast.tl`: change `teal_ast.new_env`'s declared return
  from `any, string` to `tl.Env | nil, string` (both the `record
  teal_ast` field and the function signature), and its two `@return
  any` doc comments to `@return tl.Env | nil`.
- `cosmic/_teal_engine.tl`:
  - `build_env`'s declared return changes from `any, string` to
    `tl.Env | nil, string`; drop its `env as {any: any}` cast and
    write `env.report_types = true` directly.
  - `process_source`'s `env_cache` changes from `{string: any}` to
    `{string: tl.Env}`, and its local `env` from `any` to `tl.Env |
    nil`; drop the two `as {any: any}` casts and write
    `env.loaded[name] = nil` directly.
- `_build/casts_baseline.tl`'s `cosmic/_teal_engine.tl` row moves from
  `4` to `1` — run `bin/cosmic --make run _build/casts.tl --baseline`
  and commit the result.
- `docs/design/cast-sites.tsv` drops its three now-gone rows
  (`cosmic/_teal_engine.tl` 175, 231, 232) — run `bin/cosmic --make run
  _build/cast_sites.tl --reconcile` and commit the result.
- `bin/cosmic --make ci` passes.

Re-verify these line numbers and the exact cast text against the tree
at pull time — `3IYMLDfXlYFaD39TtrxlT1AfWo4`'s merge may have shifted
them slightly from what its own spec measured.
