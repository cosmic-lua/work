## Change

Ready when: `cosmic --upgrade` reports on main (sibling item).

`cosmic --upgrade [OLD] apply` rewrites every use the report lists by
inlining the wrapper at the call site, then formats the touched files
with the formatter `--fix` uses, then prints the report again (which
should now list only `-- gone` field uses and nothing wrapped), and
`next: cosmic --make ci`. It is the transform, mechanical and
idempotent, and it edits only what the report named.

**Where the code lives.** `_tool/inline.tl` (new; `_cli/upgrade.tl`
calls it). Locate with the AST, rewrite by token span, never by regex
over source text: `tl.lex` gives tokens with `y`, `x`, `tk`
(`o/_types/types_gen/tl.d.tl:30-36,78`); `tl.parse_program(tokens,
errs, filename)` (`:79`) gives the untyped AST that
`cosmic/_teal_discard.tl` already walks with `Node = {any: any}`,
reading `kind`, `e1`, `e2`, `tk`, `y`, `x` (`sed -n 40,130p
cosmic/_teal_discard.tl` shows the callee-resolution idiom to reuse: a
call node's `e1` is the callee, its `e2` the field identifier for
`a.f(...)`).

**Algorithm**, per touched file:

1. Lex and parse. Collect `local <alias> = require("cosmic.<m>")`
   bindings (statement nodes: a `local_declaration` whose single
   expression is a call to `require` with one string).
2. For every call node whose callee is `alias.name` with `alias` bound
   to a module that has a wrapper named `name` in the running binary's
   gone tree: the span is from the callee's first token to the `)`
   that balances the call's `(`, found by walking the TOKEN stream
   (parens inside strings are not tokens, so the balance is exact);
   the arguments are the top-level comma-separated token spans inside.
3. The replacement is the wrapper's `return` expression with each
   parameter name substituted by its argument's source text, wrapped
   in parentheses when the argument is not a single token; a missing
   optional argument substitutes `nil`, and trailing `, nil` before
   the closing paren is dropped. A module alias used inside the
   wrapper (`string.`, `check.`, `rand.`) becomes the target file's
   alias for that module; if the file has none, `local <leaf> =
   require("cosmic.<m>")` is inserted after the file's last top-level
   `require` (an existing local of that name is a refusal:
   `apply: notes/render.tl needs cosmic.check but `check` is already a
   local; add the require by hand`, exit 1, file untouched).
4. Splice spans from the end of the file backward so earlier
   positions stay valid. A `require` of a module that no longer exists
   is removed once no token pair `alias .` remains.
5. Write, then `cosmic.format.format_file` (`cosmic/format/init.tl:391`)
   in place, as `--fix` does.
6. Print one line per splice: `notes/store.tl:23: hash.digest_hex("sha256", body) → hash.hex_digest(body, "sha256")`.

**What apply never does.** It does not rewrite a `-- gone` field use
(the report keeps listing it with its sentence; the fix is a judgment
about a value). It does not touch a file the report did not name. It
does not run the gate. It refuses, whole-file, on any parse error in
that file, printing tl's error.

**Why substitution is enough.** The gone-tree grammar (ratchet item)
holds every wrapper body to one `return <expression>` and every
parameter to a plain name, and the wrapper is type-checked against
the current module, so the inlined expression is well-typed wherever
the arguments were; the formatter restores house style. The
experiment's regex prototype of exactly this produced a green gate
and byte-identical behavior on the five break shapes; the AST version
removes the two places a regex can be wrong (a call spanning lines, a
paren inside a string).

Tests: `_tool/inline_test.tl` over fixture sources: each of the five
shapes; a call spanning three lines; an argument containing `)` in a
string; two calls on one line; a file already upgraded (no change, no
write); the alias-collision refusal; the removed-module require
dropped only when unused. Assert output text byte for byte, then run
`cosmic.teal.check` on the result and assert no errors.

## Non-goals

No transform for record-field changes, options values, or names with
no replacement: those stay report-only by design. No multi-hop across
releases: a project two releases behind runs apply once against the
binary it has, which carries every wrapper still in the tree.
