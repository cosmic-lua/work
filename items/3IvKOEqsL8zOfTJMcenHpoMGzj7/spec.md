## Goal

A Teal-aware structural search & replace tool, built on `tl`'s own
lexer/parser instead of regex — ast-grep/comby for Teal, with a novel
axis neither of those tools has: because `tl.check` produces a fully
typed AST, matching can eventually filter by inferred type, not just
syntax shape.

Spiked and validated in `cosmic-lua/cosmic#1732` (draft, closed without
merging — kept as a reference, not a landing target). The spike
(`docs/design/ast-rewrite/tlgrep.tl`, ~600 lines, on branch
`claude/teal-search-replace-1xq19s`) demonstrates the whole pipeline
working end to end: `$NAME`/`$$$NAME` capture syntax, a fully generic
structural matcher (statement/block patterns fall out of the same
recursion as expression patterns — no per-node-kind special-casing),
span-based text splicing that preserves formatting/comments outside a
match, replacement output piped through `cosmic.format`, and refusal
when a rewrite would silently drop a comment. Validated against 80+
real `.tl` files in this repo (1103 matches, zero crashes for a
block-level pattern) and dogfooded as a real audit: it found the exact
3 real `cosmo.*` call sites outside `cosmic/` in 304 files (all
justified with rationale comments), where a plain grep returns ~30
noisy hits.

`docs/design/ast-rewrite/README.md` (same branch) records everything
found along the way, including real bugs in the approach that a
naive port would reintroduce if not read first:

- `tl`'s own `yend`/`xend` is actively WRONG for some node kinds (not
  just absent) — traced to `tl.lua`'s `parse_list` (`tl.lua:2776-2781`)
  stamping a list node's end position using the TERMINATOR token that
  stopped it, which for a bare list with no delimiter of its own
  (`return a + b`'s `expression_list`) is a token belonging to the
  ENCLOSING block, not this node.
- `tl`'s AST has a real cycle (`if_block.if_parent` points back at its
  own `if` statement), not just shared tables.
- A generic recursive walk must check for a real position field (`y`)
  to tell "a node" from "a bare array of nodes" (`if_blocks`) — Teal's
  `is` on a generic map type structurally matches any table at
  runtime, so a naive `is {any}` fallback branch is unreachable dead
  code if placed after an `is {any:any}` check.
- Measured performance: fixed per-invocation overhead (~12ms: process
  boot + `require`s) dominates for typical files; `tl.lex`+
  `tl.parse_program` is the real bottleneck on large files, NOT the
  matcher; batching multiple files into one process measured 2.6-7x
  faster than shelling out per file, purely from amortizing that fixed
  cost.

This outcome's children port the spike into a real, tested,
gated `cosmic.ast` module plus a CLI verb — reading the spike and its
README first is the fastest way to avoid re-discovering the same bugs.
Unranked: whether and when this lands relative to other outcomes is a
call for cosmic's goal owner, not decided by the spike.
