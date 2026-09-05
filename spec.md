## Change

New `cosmic/ast/rewrite.tl` (public, `cosmic.ast.rewrite`), depending
on `cosmic.ast.node`, `cosmic.ast.walk`, and `cosmic.ast.match`. Port
from `docs/design/ast-rewrite/tlgrep.tl` (branch
`claude/teal-search-replace-1xq19s`):

- `find_all(ast: Node, pattern: Node): {Hit}` where `Hit` is
  `{node: Node, caps: {string: Node}}` — walks the whole tree (via
  `cosmic.ast.walk`) collecting every match, THEN sorts by source
  position before returning. The sort is load-bearing, not cosmetic:
  the walk falls back to `pairs()` over a node's non-array fields once
  its array part is exhausted, and Lua's hash-part iteration order is
  not guaranteed stable across runs — confirmed this matters by
  reasoning about the walk's own structure (`if_blocks`/`body` are
  both reached via `pairs`), not by observing a flip in this session,
  but the fix costs one `table.sort` and removes the risk entirely; do
  not skip it because it "seemed fine" in testing.
- Byte-offset splicing: `line_starts(source): {integer}` (precomputed
  per-line starting offsets) and `offset_of(starts, y, x): integer`
  (tl's columns are 1-based — confirmed empirically against real
  source, not assumed), used to convert each hit's
  `cosmic.ast.walk.span_start`/`span_end` into a byte range, splice the
  replacement template in back-to-front (so earlier offsets in the
  same file stay valid across multiple hits), and substitute each
  capture name in the template with `source:sub(a, b)` of its own
  span — i.e. the ORIGINAL bytes of whatever the capture matched,
  verbatim, comments and all.
- Comment-loss refusal: cross-reference the token stream's
  `.comments` attachments (a comment attaches to the token that
  FOLLOWS it, per `tl.lex`) against each hit's matched byte range;
  a comment inside the range whose position is not covered by any
  capture's OWN span that the replacement template actually reuses
  (checked via `replacement:find(capture_name, 1, true)`) would be
  silently deleted by the splice — refuse that hit (leave it
  unmodified, report why) rather than applying it. This is the
  concrete mechanism, not a TODO: it already works in the spike
  (`kept_ranges`/`dropped_comments`), confirmed by a real fixture
  (`return a --[[ keep this ]] + b` rewritten to `return b + a` is
  refused; the comment sits in the gap between the two captures, which
  the swapped template doesn't cover).
- Pipe the final spliced text through `cosmic.format.format` before
  returning it, rather than hand-preserving inter-argument whitespace:
  this also validates the splice, since `cosmic.format.format` reparses
  and reports `ok = false` on a syntax error the splice introduced —
  treat that as a hard failure (return it, don't write malformed
  output), not a warning to swallow.

## Non-goals

No CLI, no project-wide file loop, no multi-pass/fixpoint application
(a rule creating a new match of itself or another rule) — a real
fixpoint pass belongs in a LATER item modeled on `_make/converge.tl`'s
existing capped-at-two-generations pattern, not invented fresh here;
this item is single-pass, single-file only.

## Acceptance

As `cosmic/ast/rewrite_test.tl`: the `assert(os.execute($X))` rewrite
over `os.execute(cmd)` (confirms formatter round-trip on a clean
splice) and the comment-loss refusal case above (confirms a hit is
left untouched, not silently mangled, when refusing).
