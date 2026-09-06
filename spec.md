## Goal

Semantic rename for Teal ("rename this local everywhere it's actually
used, respecting scope and shadowing") is a materially bigger and
riskier investment than the syntax-only structural search/replace
outcome spiked in `cosmic-lua/cosmic#1732` — filed as its OWN outcome
rather than folded in, so it doesn't block that simpler, already-
validated work.

Investigated directly this session (read `o/3p/tl/tl.lua` at
`384d4ae8`, not inferred): `tl.symbols_in_scope(tr, y, x, filename)`
(`tl.lua:6597`) and `tl.get_token_at(tks, y, x)` (`tl.lua:1642`) look
like the obvious tools for this, but are shaped for hover/autocomplete
queries ("what's visible here, and what's the raw token text at this
exact position"), built on a scope-stack trace (`TypeReporter`'s
`symbols_by_file`, with `@{`/`@}` bracket markers, `tl.lua:6500-6546`)
— neither provides a stable per-declaration identity comparable across
two different positions the way find-references/rename needs. The
checker's actual name resolution, `TypeChecker:find_var(name, use)`
(`tl.lua:7849`), does resolve a name to a per-declaration `var` object
during checking, but that resolution is not currently persisted
anywhere queryable after the fact — confirmed by reading the
surrounding checker code AND settled empirically this session (see
Findings below): the value `symbols_in_scope` returns is not
per-declaration identity, so a from-scratch scope-aware AST walker is
the real path.

## Findings (settled this session)

**Question 1 from the prior session — is `symbols_by_file`'s per-symbol
slot (`s[4]`) comparable by identity across two use-positions of the
same local? — is a DEAD END, confirmed empirically, not just by
inspection.**

`s[4]` (returned as `scoped[name]` by `tl.symbols_in_scope`) is not an
object with reference identity at all: it is a plain Lua number, a
"typenum" produced by `TypeReporter:get_typenum(t)` (`tl.lua:6306`),
which interns by `t.typeid` — i.e. it identifies the TYPE at that
source position, not the declaration/binding. `store_type_after`
(`tl.lua:15271`) stores exactly this type value for every AST node's
position, confirming the whole `symbols_by_file`/`symbols_in_scope`
machinery is a type-report layer (this is also what tl's own
`spec/api/symbols_in_scope_spec.lua` asserts — see e.g. its `"nested
shadowing"` case, which checks `.str` type names, never declaration
identity).

Direct test (fixture + `tl.process_string` + `tl.symbols_in_scope`,
run via `o/bin/cosmic <script>.lua` against the pinned tl at v0.24.8):

```lua
local sample = [[
local x: string = "one"
print(x)
local y: string = "two"
print(y)
print(x)
]]
-- x@2 and x@5 are the SAME declaration; y@4 is a DIFFERENT declaration
-- (same declared type "string")
```
Output:
```
x@2 slot:	7	number
x@5 slot:	7	number
y@4 slot:	7	number
x@2 == x@5 (same declaration, two uses)?	true
x@2 == y@4 (DIFFERENT declarations, same type)?	true
```

Worse, the exact shadowing case rename must respect collides too:

```lua
local sample = [[
local a: string = "outer"
print(a)
do
  local a: string = "inner"
  print(a)
end
print(a)
]]
```
Output:
```
outer@2:	7	 inner@5:	7	 outer@7:	7
outer@2 == outer@7 (same decl)?	true
outer@2 == inner@5 (DIFFERENT decl, same type, shadowed)?	true
```

The outer declaration and its own shadowing inner declaration return
the identical slot value. `symbols_in_scope`'s slot cannot disambiguate
two different bindings of the same name and type — the single most
important case for a rename tool to get right. This is a structural
mismatch (the layer tracks types, not bindings), not a missing feature
a small carried patch could plausibly bridge in the shape `tl.lua`
already exposes; per this item's own Non-goals, that rules out chasing
a `tl.lua` patch and confirms path (2) below.

Note on the prior session's phrasing: "compare the returned slot by
reference" doesn't quite apply — the slot is a Lua number, which has no
reference identity distinct from its value. The decisive experiment
was a value-collision test (do two different declarations produce the
same slot?), not an identity test; that phrasing is worth avoiding in
future specs probing this API.

**Consequence for (2), the from-scratch walker:** confirmed still
blocked on `cosmic.ast` landing (no such module exists in the tree at
`384d4ae8`; `cosmic/_teal_ast.tl` is an unrelated, internal, `_`-prefixed
module that thaws pre-parsed stdlib ASTs for startup performance, not
a general AST-manipulation layer). The binding-introducing / scope-
delimiting node kinds named in the prior session's writeup
(`local_declaration`, `local_function`, a function's parameter list,
`statements`) all exist in the pinned tl parser exactly as described
(`tl.lua:4620`, `:3657`, `:3520-3523`, `:4732`) — but the walker also
needs to treat `forin` (`tl.lua:5277`) and `fornum` (`tl.lua:5284`)
loop-variable introduction as binding sites too; the prior session's
three-node-kind list was incomplete. A value reference itself is node
kind `"variable"` (`tl.lua:5121`, `:4407`), not `"identifier"`
(`"identifier"` is a distinct, rarer node kind used e.g. for labels).

No build items are filed as this research item's children yet: the
walker's shape is genuinely not clear until `cosmic.ast` lands (its own
outcome), and guessing the file split now is exactly what this item's
own spec says not to do. The next session that picks this up, once
`cosmic.ast` exists, should decompose scope-tracking (a stack of
binding tables keyed by node nesting) from name resolution (walk that
stack to a declaration id) from the rename operation itself (collect
all `"variable"` references whose resolved declaration id matches, plus
the declaration's own name token) as the natural file split, but that
split is not committed here.

## Change — SETTLED

1. ~~Whether `symbols_by_file`'s per-symbol type slot is comparable by
   identity across two use positions of the same local~~ — SETTLED: NO.
   Confirmed by direct test (see Findings): the slot is a type-identity
   number, and it collides across different declarations that share a
   type, including the shadowing case. Semantic rename cannot be built
   on `symbols_in_scope`.
2. From-scratch scope-aware AST walk over `cosmic.ast` is confirmed as
   the real path (see Findings) — still blocked on `cosmic.ast` landing.
   No children filed yet; the next session's first move is filing the
   concrete build items once `cosmic.ast`'s shape is known, using the
   corrected binding-site list above (adds `forin`/`fornum` to
   `local_declaration`/`local_function`/parameter lists).

## Non-goals

Not attempting to change or extend `tl` itself (no upstream patch) —
this outcome works with what the pinned `tl` already exposes, or with
cosmic's own AST layer once it exists, never by adding new plumbing to
`tl.lua` via the carried-patch mechanism. This session's findings
confirm the gap is structural (a type-report layer used for a
binding-identity purpose it isn't shaped for), not a small missing
annotation `tl.lua` could plausibly grow — so this non-goal is
reaffirmed, not merely still assumed.
