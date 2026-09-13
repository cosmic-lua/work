`96afd807` curated `tl.Env` and, to satisfy `tl.process_string`'s now-typed
parameter, added `env as tl.Env` at `cosmic/_teal_engine.tl:240` and
`cosmic/_teal_ast_test.tl:52`. Under the pinned bootstrap with its embedded
types — the state generation 1 is in before `_types/types_gen.tl` has run —
both lines are refused with `unknown type tl.Env` (Evidence). They pass the
cold `repro` lane anyway because neither file is compiled from the tree in
that window: `cosmic/searcher.tl`'s re-entrancy guard (`compiling`, 262-283)
makes the tree searcher miss while a tree module compiles, so `cosmic.teal`
and with it `cosmic._teal_engine` load from `/zip`; and `_teal_ast_test.tl`
is only compiled at test time. By the time generation 1 compiles
`_teal_engine.tl` itself, `o/_types/types_gen/tl.d.tl` exists and carries
`Env`. Item 3IortEJ5fOuRnJ7OpJMfuXzMkSX failed on exactly this window because
it edited `cosmic/_teal_ast.tl`, which the `/zip` engine requires FROM THE
TREE (`_teal_engine.tl:165`) and therefore compiles against embedded types.

Recommendation: record, do not move. The cast at `_teal_engine.tl:240` IS the
engine — there is no file outside the bootstrap chain to move it to that
still satisfies the typed parameter — and both casts are deleted by
3IortEJ5fOuRnJ7OpJMfuXzMkSX once `bin/cosmic.pin` (today
`2026-08-31-a5b36f4`) points at a release carrying the curation. What is
missing is the reason, so the next reader does not "fix" a green build.

`cosmic/_teal_engine.tl` (412 lines) and `cosmic/_teal_ast_test.tl` (63
lines): replace each cast's trailing comment with one that says (a) the cast
satisfies the curated parameter until `build_env`/`new_env` return `tl.Env`;
(b) the pinned bootstrap's embedded `tl.d.tl` has no `Env`, so this line
fails `--check types` under the bootstrap alone; (c) it survives a cold build
because this file is never compiled from the tree before `_types/types_gen.tl`
has produced `o/_types/types_gen/tl.d.tl` — the searcher's compile guard
loads the engine from `/zip` — and `cosmic/_teal_ast.tl` does NOT enjoy that
(it is required from the tree by the `/zip` engine), so no `tl.Env` may
appear there before the pin bump. Keep the `-- cast:` marker first on the
line so `_build/casts.tl` still counts it; `_build/casts_baseline.tl` and
`docs/design/cast-sites.tsv` are unchanged.
