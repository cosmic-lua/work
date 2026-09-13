New `cosmic/ast/walk.tl` (public, `cosmic.ast.walk`), depending on
`cosmic.ast.node`'s `Node` record (item filed alongside this one under
the same outcome — take that one first). Port two things from
`docs/design/ast-rewrite/tlgrep.tl` (branch
`claude/teal-search-replace-1xq19s`), both hardened by bugs this
session found and fixed by actually running the spike, not by reading
`tl`'s source alone:

1. **A generic, cycle-guarded walk** (`walk(node: Node, visit: function(Node))`),
   modeled on `tlgrep.tl`'s `collect`/`consider` but corrected: the
   FIRST version of this walk in the spike never descended into a
   bare-array field (`if_blocks`) at all, because Teal's `is` on a
   generic map type (`{any:any}`) matches any table at runtime, so a
   fallback branch written as `elseif v is {any} then ... end` placed
   after an `is {any:any}` check was unreachable dead code — confirmed
   by instrumenting the spike and watching an `if`-statement pattern
   match nothing until the walk was rewritten to check the actual `y`
   field (does this child have its own position, i.e. is it a real
   node) rather than trying to distinguish the two structural aliases
   by `is`. Port the corrected shape (real code in the current
   `tlgrep.tl`'s `node_start`/`node_end` `consider()` closures — the
   comment there names the exact fix), not the original.
2. **Span computation** (`span_start(node: Node): integer, integer` /
   `span_end(node: Node): integer, integer`, line/column, 1-based),
   because `tl` only calls `end_at` at ~12 parser call sites (grep
   `end_at(` in `o/3p/tl/tl.lua` at pull time to re-confirm the exact
   count against the pinned version) — an arbitrary node has no
   built-in end position, and where one exists it is SOMETIMES wrong
   for this purpose: `tl.lua`'s `parse_list` (`tl.lua:2776-2781`)
   stamps a list node's `yend`/`xend` using the TERMINATOR token that
   stopped it, correct when that terminator is a real delimiter
   belonging to the node (a call's `)`), but for a bare list with none
   of its own (`return a + b`'s `expression_list`, stopped by the
   ENCLOSING block's `end` three lines later) it points at someone
   else's token. Same `kind` (`expression_list`) is both cases. Port
   the spike's resolution: trust `yend`/`xend` unconditionally only for
   `kind == "statements"` (a block's own close is the ONLY place its
   true end lives — an empty or short block has no descendant token
   that reaches it), and everywhere else, check the actual source
   character at the reported position (trust it only when it's a real
   close-bracket: `)`, `]`, `}`), otherwise recurse to the real
   leftmost/rightmost descendant leaf token instead.
