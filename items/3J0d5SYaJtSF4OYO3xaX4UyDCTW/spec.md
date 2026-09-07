## Change

`cosmic.ast` gains a narrow, structural require-alias resolver:
`cosmic.ast.requires(parsed: Parsed): {string: string}` (new function
in `cosmic/ast/init.tl`, implementation in a new `cosmic/ast/requires.tl`
— `cosmic/ast/init.tl` is 39 lines today, `grep -c '' cosmic/ast/init.tl`,
so the new file follows the existing one-concern-per-file convention
`walk.tl`/`match.tl`/`rewrite.tl` already set rather than growing
`init.tl` itself).

**Scope, deliberately narrow.** Top-level `local <alias> =
require("cosmic.<m>")` statements only — a `local_declaration` node
whose single expression is a call to the identifier `require` with one
string-literal argument beginning `cosmic.`. Returns `{alias:
module_name}` (e.g. `{hash = "cosmic.hash"}`), built with one
`cosmic.ast` pattern (`compile_pattern("local $ALIAS = require($M)")`)
matched via `ast.find_all` against the file's top-level `statements`
node only (not walked into nested blocks — a `local` inside a function
body binds a local variable, not a module alias, and is out of scope).
No shadowing, no re-assignment tracking, no loop-bound aliases, no
resolution through an intermediate local (`local h = hash; h.digest(...)`
is not resolved). Two call sites already independently plan this exact
scan by hand: `«BDFQ_7gGe»`'s `_tool/inline.tl` (revised to depend on
this item) and `«MLM8_HLpJ»`'s report scan (`local <alias> = require(...)`
bindings, same shape) — this item gives both one shared primitive
instead of two divergent re-derivations of the same pattern.

**Why not general scope-aware resolution.** Investigated and rejected
at that scope in `«HlZW_zWbs»` (completed research): `tl.symbols_in_scope`
exposes TYPE identity, not per-declaration identity (two different
declarations of the same type collide, including the shadowing case),
so a general "does this reference resolve to that binding" resolver
needs a from-scratch scope-aware AST walk tracking `local_declaration`,
`local_function`, parameter lists, `forin`/`fornum` loop variables, and
block (`statements`) boundaries as scope frames — real work, and
strictly more than either current consumer needs. This item is the
narrow slice both consumers actually asked for: a top-level,
un-shadowed, un-reassigned module alias, which needs none of that
machinery.

**Tests** (`cosmic/ast/requires_test.tl`, new): a plain single alias;
two aliases; a non-`cosmic.` require (not returned); a require inside
a function body (not returned — top-level only); a re-assigned alias
(`local hash = require("cosmic.hash"); hash = other_thing` — documents
the scope limit: still returned as bound to `cosmic.hash`, since
tracking reassignment is explicitly out of scope, not a bug); a file
with no requires at all (empty table, not nil).

## Non-goals

No shadowing, re-assignment, or loop-variable resolution — see
`«HlZW_zWbs»` for why that is materially larger work, tracked
separately if a future consumer needs it. No resolution of an alias
bound to another local rather than directly to `require(...)`.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

Pullable now — `cosmic.ast.parse`/`.match`/`.walk` are all `done`.
