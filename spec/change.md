- `_types/gentype_parse.tl`: keep the failure fold; additionally
  collect every `---@overload fun(<params>): <returns>` whose return
  list does not start with `nil` into an `overloads` list on the
  binding entry. A param spelled as a constant (`unix.SOL_SOCKET: integer`)
  is positional: keep only its type. A named return (`flags: integer`,
  `seconds: integer, enabled: boolean`) keeps only its type. An
  overload whose params or returns the existing type converter cannot
  render is skipped and counted; `_types/gentype_test.tl` asserts that
  count so a regression in coverage is visible.
- `_types/gentype_render.tl`: after the primary line emit one
  `name: function(<params>): <returns>` per collected overload. When
  the primary is fallible, append the same folded error tuple to the
  overload (`true` → `boolean | nil, string, Errno`): the C entry is
  one function (`third_party/lua/cosmo/lunix.c:2211`, `SysretBool`),
  so its failure shape is the primary's.
- `_types/gentype_test.tl`: a case feeding bind's block above and
  expecting two `bind:` lines; one for setsockopt's constant-typed
  params.
- `cosmic/net/socket.tl:334, 397, 437` and `cosmic/net/connect.tl:95`:
  delete the casts, call the binding directly.
- `_build/casts_baseline.tl`: `cosmic/net/socket.tl` 3 → gone,
  `cosmic/net/connect.tl` 1 → gone; reconcile
  `docs/design/cast-sites.tsv`. If `### function shape` has no rows
  left (the six other rows are `respec 6sv6`), delete that heading
  from `docs/design/casts.md` — whichever of the two lands second
  does it.
- Cold build: the consumer sites are checked in generation 1 against
  types the TREE's generator wrote (generators run before the graph),
  so no pin bump is expected; prove it with
  `rm -rf o && bin/cosmic --make fetch && bin/cosmic --make build`
  before opening the PR. `bin/cosmic --make ci` ends `ci: PASS`.
