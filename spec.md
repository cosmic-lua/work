## Change

Ready when: `cosmic --upgrade` reports on main (sibling item, `«MLM8_HLpJ»`)
AND `cosmic.ast`'s require-alias resolution primitive is `done`
(sibling item, filed alongside this revision — see Dependency below).

`cosmic --upgrade [OLD] apply` rewrites every use the report lists by
inlining the wrapper at the call site, then formats the touched files
with the formatter `--fix` uses, then prints the report again (which
should now list only `-- gone` field uses and nothing wrapped), and
`next: cosmic --make ci`. It is the transform, mechanical and
idempotent, and it edits only what the report named.

**Revision note.** The original version of this spec planned to parse
with raw `tl.parse_program` and walk an untyped `Node = {any: any}`
tree (`cosmic/_teal_discard.tl`'s idiom), locate calls by manually
balancing parens over the token stream, and splice replacements by
hand-computed byte spans. `cosmic.ast` (`cosmic.ast.match`,
`cosmic.ast.rewrite`) has since landed and already does exactly the
locate-and-splice half of that job — pattern match with `$NAME`
captures, splice the ORIGINAL bytes of each capture into a replacement
template, refuse a hit that would silently drop a comment, reformat
the result through `cosmic.format`. Re-deriving that machinery by hand
here would be a second, divergent implementation of
`cosmic/ast/rewrite.tl`'s own `rewrite()`. This revision uses it
directly instead.

**Where the code lives.** `_tool/inline.tl` (new; `_cli/upgrade.tl`
calls it), built on `cosmic.ast.match.compile_pattern`,
`cosmic.ast.parse`, and `cosmic.ast.rewrite.rewrite`
(`cosmic/ast/rewrite.tl:290-317`, `function(source: string, name:
string, pattern: Node, replacement: string): RewriteResult | nil,
string`).

**Dependency: require-alias resolution.** `cosmic.ast.match` matches
SHAPE, not bound identity — a pattern `$ALIAS.digest_hex($$$ARGS)`
matches any call spelled that way regardless of what `$ALIAS` is
actually bound to, so it cannot by itself restrict to "only when
`$ALIAS` resolves to `require("cosmic.hash")`". This item needs a
per-file resolver — filed alongside this revision as its own
`cosmic.ast` primitive — that reads a file's top-level `local <alias>
= require("cosmic.<m>")` bindings and returns `{alias: module_name}`.
Scoped narrowly (top-level bindings only, no shadowing, no
re-assignment, no loop variables) — full scope-aware binding
resolution was investigated and found materially harder
(`«HlZW_zWbs»`, completed research: `tl.symbols_in_scope` exposes type
identity, not declaration identity, so a general resolver needs a
from-scratch scope-aware walk); this item's need is the narrow case
that walk was never required for. `_cli/upgrade.tl`'s sibling report
item (`«MLM8_HLpJ»`) independently plans the identical
`local <alias> = require(...)` scan for its own use — the primitive is
shared, not duplicated between the two.

**Algorithm**, per touched file:

1. Resolve require-aliases (the dependency above) to get `{alias:
   module_name}` for the file.
2. For each `alias -> module_name` pair where the running binary's
   `cosmic/_gone/<module_name>.tl` names one or more wrappers: for
   each wrapper, read ITS OWN source with `cosmic.ast.parse` and pull
   its parameter name list and its single `return <expression>` body
   (the gone-tree grammar, a sibling ratchet item, holds every wrapper
   to exactly this shape).
3. Build one `cosmic.ast` pattern PER CALL ARITY the wrapper accepts —
   a wrapper with an optional trailing parameter needs two
   pattern/replacement pairs, one per arity, since a compiled pattern
   matches a fixed argument count. Reuse the wrapper's OWN parameter
   names as the pattern's capture names, e.g. wrapper
   `function digest_hex(data, algo?)  return hash.digest(algo, data)
   end` compiles to `alias .. ".digest_hex($data, $algo)"` (full
   arity) and `alias .. ".digest_hex($data)"` (optional arg omitted).
4. The replacement template for each arity is the wrapper's own
   `return` expression source text VERBATIM, with the omitted-arg
   variant substituting the literal `nil` for the missing parameter
   name wherever it appears (a second pass of `cosmic.ast.rewrite`'s
   own `$NAME` substitution rules cannot do this — the wrapper's
   return expression is fixed text with the parameter identifier
   spelled in it, so the omitted-arg replacement is built by replacing
   that identifier's own token text before compiling the template,
   not by matching it as a capture).
5. Call `cosmic.ast.rewrite.rewrite(source, path, pattern,
   replacement)` once per (wrapper, arity) pair found in the file,
   threading `source = result.code` between calls so later patterns
   see earlier splices — `rewrite` is documented single-pass,
   single-file; composing multiple wrapper replacements in one file is
   this caller's own loop, not a new capability.
6. Collect every `RewriteResult.refused` entry across all calls and
   print them as the report's `-- gone` style lines instead of
   applying them — a hit `rewrite` refused (would drop a comment) is
   the same "stays report-only" outcome the original spec already
   reserved for record-field changes.
7. A module alias used inside the wrapper's own return expression
   (`string.`, `check.`, `rand.`) becomes the target file's alias for
   that module; if the file has none, `local <leaf> =
   require("cosmic.<m>")` is inserted after the file's last top-level
   `require` (an existing local of that name is a refusal:
   `apply: notes/render.tl needs cosmic.check but 'check' is already a
   local; add the require by hand`, exit 1, file untouched).
8. A `require` of a module that no longer has any surviving use (no
   `alias .` token pair left after all splices) is removed.
9. Write, then `cosmic.format.format_file` (`cosmic/format/init.tl:391`)
   in place — belt and suspenders alongside `rewrite`'s own internal
   `cosmic.format.format` pass, since `format_file` is what `--fix`
   itself calls and this item's output should match that path exactly.
10. Print one line per splice: `notes/store.tl:23:
    hash.digest_hex("sha256", body) → hash.hex_digest(body, "sha256")`.

**What apply never does.** It does not rewrite a `-- gone` field use
(the report keeps listing it with its sentence; the fix is a judgment
about a value). It does not touch a file the report did not name. It
does not run the gate. It refuses, whole-file, on any parse error in
that file (`cosmic.ast.parse`'s own error), printing it.

**Why substitution is enough.** The gone-tree grammar (ratchet item)
holds every wrapper body to one `return <expression>` and every
parameter to a plain name, and the wrapper is type-checked against
the current module, so the inlined expression is well-typed wherever
the arguments were; the formatter restores house style. The
experiment's regex prototype of exactly this produced a green gate
and byte-identical behavior on the five break shapes; the AST version
(now via `cosmic.ast.rewrite` rather than a hand-rolled second
implementation of it) removes the two places a regex can be wrong (a
call spanning lines, a paren inside a string) and reuses the same
comment-loss refusal `cosmic.ast.rewrite` already tests, instead of
this item re-deriving that safety check on its own.

Tests: `_tool/inline_test.tl` over fixture sources: each of the five
shapes; a call spanning three lines; an argument containing `)` in a
string; two calls on one line; a file already upgraded (no change, no
write); the alias-collision refusal; the removed-module require
dropped only when unused; a wrapper with an optional argument, called
both with and without it; a call whose inlining would drop a comment
(refused, reported, file unchanged at that site). Assert output text
byte for byte, then run `cosmic.teal.check` on the result and assert
no errors.

## Non-goals

No transform for record-field changes, options values, or names with
no replacement: those stay report-only by design. No multi-hop across
releases: a project two releases behind runs apply once against the
binary it has, which carries every wrapper still in the tree. No
general scope-aware binding resolution (shadowing, re-assignment,
loop-bound aliases) — the require-alias dependency is intentionally
narrower than the `«HlZW_zWbs»` investigation's scope; a file that
rebinds an alias mid-function is out of scope and apply skips uses
past the rebinding (report continues to list them).
