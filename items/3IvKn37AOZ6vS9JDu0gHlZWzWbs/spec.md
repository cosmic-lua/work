## Goal

Semantic rename for Teal ("rename this local everywhere it's actually
used, respecting scope and shadowing") is a materially bigger and
riskier investment than the syntax-only structural search/replace
outcome spiked in `cosmic-lua/cosmic#1732` — filed as its OWN outcome
rather than folded in, so it doesn't block that simpler, already-
validated work, and because this session's investigation found the
obvious-looking primitives are the wrong ones, which the next session
should not have to re-discover.

Investigated directly this session (read `o/3p/tl/tl.lua`, not
inferred): `tl.symbols_in_scope(tr, y, x, filename)` (`tl.lua:6597`)
and `tl.get_token_at(tks, y, x)` (`tl.lua:1642`) look like the obvious
tools for this, but are shaped for hover/autocomplete queries ("what's
visible here, and what's the raw token text at this exact position"),
built on a scope-stack trace (`TypeReporter`'s `symbols_by_file`, with
`@{`/`@}` bracket markers, `tl.lua:6500-6546`) — neither provides a
stable per-declaration identity comparable across two different
positions the way find-references/rename needs. The checker's actual
name resolution, `TypeChecker:find_var(name, use)` (`tl.lua:7849`),
does resolve a name to a per-declaration `var` object during checking,
but that resolution is not currently persisted anywhere queryable
after the fact — confirmed by reading the surrounding checker code,
not by testing (this was as far as this session's time budget went;
whether `symbols_by_file`'s stored slot happens to be comparable by
identity across positions was flagged as an open question, not
settled — the next session's first move should be settling it before
assuming a from-scratch walker is necessary).

## Change

This item's own deliverable is research, not code (per the board's own
sizing rule: "research is an item whose deliverable is recorded
findings and follow-up items, not code"). Settle, with real commands
and pasted output:

1. Whether `TypeReporter.symbols_by_file`'s per-symbol type slot (`s[4]`
   in `tl.lua`'s `symbols_in_scope`) is comparable BY IDENTITY across
   two different USE positions of the same local — if so, semantic
   rename is a much smaller lift than a from-scratch walker (a few
   `tl.check` calls plus a comparison), and that becomes this outcome's
   first buildable child. Test directly: check two different reference
   positions of the same local in a small fixture and compare the
   returned slot by reference, not by value.
2. If (1) is a dead end: scope out a from-scratch scope-aware AST walk
   over `cosmic.ast` (once that outcome lands — this one depends on it)
   as the real path: Teal's scoping is strict block-lexical scoping
   already fully recoverable from the same node nesting the structural
   matcher walks (`local_declaration`/`local_function`/a function's own
   parameter list introduce bindings; `statements`/block nodes delimit
   their lifetime and shadowing follows nesting). File the concrete
   build items this decomposes into as this research item's own
   children once the shape is clear, rather than guessing the file
   split now.

## Non-goals

Not attempting to change or extend `tl` itself (no upstream patch) —
this outcome works with what the pinned `tl` already exposes, or with
cosmic's own AST layer once it exists, never by adding new plumbing to
`tl.lua` via the carried-patch mechanism unless (1) above turns up a
concrete gap only a patch can close.
