- The consumer-side change `3IortEJ5fOuRnJ7OpJMfuXzMkSX` owns —
  `build_env`'s, `process_source`'s, and `teal_ast.new_env`'s DECLARED
  return types, `env_cache`'s declared type, and the two `{string:
  any}` casts at `_teal_engine.tl` lines ~231-232 — is unchanged by
  this item. This item adds exactly the two narrow, temporary `env as
  Env` casts named in Change, forced into existence by curating `Env`
  at all, not a step toward that follow-up's broader retyping.
- The other 15 of the 18 `tl compiler surface` sites stay open
  (raw `Node`-field reads — see Goal). `tl.Node` is upstream a
  deliberately empty interface; closing these needs a
  `teal-language/tl` change, and **no session working this board has
  push/PR access to that repository**; do not attempt an upstream tl
  PR from here.
- `_types/tlast.tl:106` and `:331`: this file `load()`s a *second*,
  private copy of `tl.lua` rather than using `require("tl")`, so
  `_types/gentl.tl`'s curated type never applies to it. Not in scope.
- `cosmic/_teal_discard.tl:258` (`rep["get_report"]`): an independent
  change (curating `TypeReporter`/`TypeReport` and reshaping
  `issues()`'s signature); leave it for a later item.
- Do not curate any other `Env` field (`globals`, `modules`,
  `module_filenames`, `loaded_order`, `reporter`, `keep_going`,
  `defaults`) — none is read by a site in this class.
- Do not touch `3p/tl/tl_pin.tl` — this change needs no pin bump.
