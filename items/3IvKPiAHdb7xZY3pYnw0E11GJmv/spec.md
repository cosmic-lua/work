## Change

New `cosmic/ast/node.tl` (public module, `cosmic.ast.node`): a real
`Node` record for `tl`'s parser output, replacing the erased `any` that
`_types/gentl.tl` currently produces for it (`RECORD_FIELDS` in
`_types/gentl.tl` keeps `Token`/`Comment`/`Error`/etc. as named records
but not `Node` — confirmed by reading `_types/gentl.tl`'s `FUNCTIONS`/
`RECORD_FIELDS` tables, neither lists `Node`). Every current internal
consumer (`_tool/coverage/lines.tl:13-19`, `_tool/discover.tl`) instead
re-declares its own narrow local `Node` record with only the fields it
personally touches — this item is the one real, complete declaration
those can eventually converge on (not part of this item's diff; do not
touch existing callers).

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

## Non-goals

No walk, no matcher, no rewrite logic here — those are separate items
(file-disjoint siblings under the same outcome) so this PR stays small
and the `Node` record is reviewable on its own.

## Acceptance

A conformance test (`cosmic/ast/node_test.tl`) in the spirit of
`_types/gentl.tl`'s own ratchet against the pinned `tl` source
(`_types/gentl.tl`'s `tl_conformance_test.tl` sibling is the existing
precedent to follow, not duplicate): parse a handful of small fixture
snippets (one per kind covered) against the CURRENT `o/3p/tl/tl.lua`
and assert the `Node` record's fields actually appear with the
expected shape. This is what catches a `tl` pin bump reshaping a node
before it silently breaks every downstream consumer, not a one-time
check — write it as a real, permanent test, not a comment.
