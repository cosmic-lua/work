New `cosmic/ast/node.tl` (public module, `cosmic.ast.node`): a local
`Node` record modeling `tl`'s real parser-output shape, built by
casting `tl.parse_program`'s erased `any` return the same way every
current consumer already does at its own call site.

Port from `docs/design/ast-rewrite/tlgrep.tl` (branch
`claude/teal-search-replace-1xq19s`, reference only — read it, don't
just skim the README):

- A `Node` record covering the fields actually observed across the
  ~40 `kind` values this session probed directly (paste each probe's
  command + output into the spec when re-measuring at pull time; the
  ones already measured this session: `op`/`variable`/`identifier`/
  `string`/`if`/`if_block`/`statements`/`return`/`expression_list` —
  see the README's "Findings" section for the exact field lists, e.g.
  an `op` node is `{kind, f, y, x, e1, e2, op: {op: string}}` with NO
  `tk`, an `if_block` carries `if_parent` pointing back at its own
  enclosing `if` (a real cycle, not shared-table aliasing)). Fields not
  common to every kind are optional (`e2?: Node` — unary ops have no
  `e2`).
- `parse(source: string, name: string, lang?: string): Node | nil,
  {tl.Token}, string` — wraps `tl.lex` + `tl.parse_program` exactly as
  `tlgrep.tl`'s own `parse()` does (lines ~230-247 there), returning
  the token stream alongside the AST since a later item (comment-loss
  detection) needs both from one parse, not two.
