Declare the tl syntax-tree fields the coverage walker reads as a record
LOCAL to `_tool/coverage/lines.tl`, and index it as a record. One file
plus one baseline row; no other file moves.

**1. Add the record** directly after `local tl = require("tl")` (line 8):

```teal
--- The tl syntax-tree fields this walker reads.
--- A narrow view of tl's own AST node: `tl.parse_program` returns it as
--- `any`, and the fields below are the only ones a line walk touches.
local record Node
  kind: string
  y: integer
  exp: Node
  exps: Node
  if_blocks: {Node}
end
```

**2. Retype `mark_statement`** (today `_tool/coverage/lines.tl:28`): its
first parameter becomes `Node` instead of `{any: any}`, its `@param`
tag becomes `@param node Node`, and every bracketed read becomes a
field read — `node.kind`, `node.y`, `node.exps`, `node.exp`,
`node.if_blocks`, `exp.y`, `block.exp`, `block.y`. All six
`-- cast: from any` comments in this function go with the casts they
justified. The branch structure, `exec_kinds`, the comments explaining
why `repeat`/`if`/function definitions are handled as they are, and the
`if not kind or not y then return end` guard all stay exactly as they
are.

**3. Narrow with `Node` at the one call site.** In `walk`, the
statements-child guard `if child is {any: any} then` becomes
`if child is Node then`. Both compile to the same test — verified on
this tree, `grep -n 'type(child)' o/_tool/coverage/lines.lua` prints
`if type(child) == "table" then` before and after — so `mark_statement`
takes a `Node` with no cast at the boundary and the walk's behaviour is
byte-identical.

**4. Leave `walk` and `executable_lines` alone.** `walk` keeps its
`{any: any}` parameter and its two `-- cast: array view of ast map`
casts (`:75`, `:87`), and `executable_lines` keeps the
`-- cast: ast node as generic map` at `walk(ast as {any: any}, ...)`
(`:122`). The recursive traversal visits every field of an arbitrary
node, including fields this record deliberately does not name; a record
cannot express that, so those three casts are correctly reasoned and
stay. Only the six `from any` casts close.

**5. Regen the cast floor.** `bin/cosmic --make run _build/casts.tl
--baseline`, then commit `_build/casts_baseline.tl`. That is the exact
command the gate's failure message prints; no gate is weakened any other
way.

**Measured 2026-08-25 against `1f9279ab`**, each with the command that
produced it, and each re-measured with the change applied:

| command | today | after |
| --- | --- | --- |
| `grep -c -- "-- cast: " _tool/coverage/lines.tl` | 9 | 3 |
| `grep -c -- "-- cast: .*from any" _tool/coverage/lines.tl` | 6 | 0 |
| `wc -l < _tool/coverage/lines.tl` | 134 | 145 |
| `grep -n '"_tool/coverage/lines.tl"' _build/casts_baseline.tl` | `= 9` | `= 3` |

145 lines leaves 355 of headroom under the 500-line cap, so placing the
record in this file is not a capacity question.

**Why hand-declared, and not generated from the pin.** This was the
item's open decision; it is settled, and the generated route is not
available. Measured against the pinned tl (`o/3p/tl/tl.tl`, v0.24.8,
after `bin/cosmic --make fetch`):

- `_types/gentl.tl`'s `verify_record` looks for `"\n%s+record <Name>\n"`
  — an INDENTED declaration inside `record tl`. tl declares its AST node
  as `local record Node` at column 0: `grep -n "^local record Node$"
  o/3p/tl/tl.tl` prints `2201:local record Node`. The pattern cannot
  match it. The only indented `Node` inside `record tl` is an empty
  abstract `interface Node end`: `grep -n "^   interface Node$"
  o/3p/tl/tl.tl` prints `674`.
- Even found, a curated field subset naming `y` would fail
  verification: `Node` gets `y`/`x` from `is {Node}, tl.Node, Where`,
  not from its own body, and `verify_record` matches field names inside
  the body only.
- `tl.d.tl` is the PUBLIC tl surface the artifact ships as the types
  user scripts see for `require("tl")`. Widening it with tl's internal
  AST — 60+ fields that move at every pin bump — to serve one internal
  `_tool/` walker is a cost `_tool/**` has no business imposing.

`cosmic/_teal_ast.tl`, named as a candidate when this item was filed, is
not one: it thaws the pre-parsed stdlib AST cache for `tl.new_env` and
declares no node shape. It is unrelated to this slice.

**Public surface.** `_tool/**` never ships in a user artifact and
`_build/public_surface_baseline.tl` is keyed by `cosmic.*` module name
only — `grep -c "_tool" _build/public_surface_baseline.tl` prints `0`.
This slice moves no public surface.
