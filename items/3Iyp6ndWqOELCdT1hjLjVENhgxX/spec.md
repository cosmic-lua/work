## Evidence

`o/bin/cosmic --find '$X as $T' cosmic` → `find: refused: <pattern>:1:9: syntax error` and `--find 'foo($X) as $T' cosmic` → `syntax error` at `:1:14` (2026-09-07): a cast cannot be written as a pattern, so none of the 16 cast kinds in `docs/design/casts.md` can be selected by `--find`, and «the allowlist test» has nothing to match with. The parser's shape, probed with `cosmic.ast.parse` + `walk`: a cast is an `op` node with `op.op == "as"`, `e1` the operand, `e2` a node of kind `cast` whose `casttype.typename` is the type's kind (`integer`, `map`, `record`, …) and whose `tk`/`casttype` render the type text; `cosmic/ast/match.tl`'s `desugar` (`:73`) turns `$NAME` into an identifier and `match_list` (`:142`) compares nodes by kind and fields — there is no branch for `casttype`. `_build/cast_sites.tl:205` finds the same node by hand (`n.kind == "op" and n.op and n.op.op == "as"`).

## Change

`cosmic/ast/match.tl`: a pattern may contain `EXPR as TYPE`, where `TYPE` is either a literal Teal type (`integer`, `{string: any}`, `Foo`) that matches when the cast's rendered type text equals it, or a capture `$T` that binds the `cast` node (and, for `$T:PATTERN`, applies the name predicate to the rendered type text, so `$X as $T:^{` selects every cast to a map or array). `desugar` leaves the `as` in place (it is valid Teal) and `match_value` gains the `cast` branch comparing `casttype` structurally for a literal type and binding it for a capture; `--find`'s hit rendering prints the cast's line as today. `cosmic/ast/match_test.tl`: `$X as integer` binds the first probe cast and not the map one; `$X as $T` binds both with `$T` the cast node; `$X as $T:^{` binds only the map; `f($A) as Foo` matches a call operand. `cosmic/ast/init_example.tl` gains one `Example_find_casts`. `docs/guides/` page for `--find` (wherever #1763 documented the grammar) gains the `as` line.

## Non-goals

No `--rewrite` of a cast's type (a later item); no type-aware matching beyond rendered text equality.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`o/bin/cosmic --find '$X as $T' cosmic _cli _make _tool _build` prints `find: 138 hit(s)` (the current tsv row count, ±rows landed since) and `--find '$X as {string: any}' cosmic` prints only the map-view casts.
