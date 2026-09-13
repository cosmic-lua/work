`cosmic.js.escape_literal` (`cosmic/js.tl:15-17`) is `cosmo.EscapeLiteral`
verbatim. That table passes `` ` ``, `$` and `{` through and renders `"` as
`\"` (Evidence). Two consequences: a `{{js .x | cosmic.js.safe}}` inside a JS
template literal lets `${alert(1)}` through, and inside an `onclick="..."`
attribute the `\"` is a bare `"` to the HTML tokenizer (backslash is not an
attribute escape), ending the attribute.

`cosmic/js.tl` (57 lines): after `cosmo.EscapeLiteral(str)`, apply one
`gsub` over the result mapping exactly `` ` `` → `\u0060`, `$` → `\u0024`,
`{` → `\u007b`, `}` → `\u007d`, and the two-byte sequence `\"` → `\u0022`.
The first four never appear escaped in `EscapeLiteral`'s output (the table
passes them through), and `"` only ever appears as `\"` (it is never passed
bare), so a single pass over the escaped string is exact — pin that with the
tests below rather than arguing it. Rewrite the doc comment at 4-14 to state
the contract precisely: the output is the CONTENT of a `'`- or `"`-quoted
JavaScript string literal inside a `<script>` block; the template author
writes the quotes; not for template literals (the escaping makes them safe
but the context is not what `SafeJs` promises), not for `on*=` attributes,
not for a bare expression slot. Update `cosmic/js_example.tl` if its comment
at 4 or 18 contradicts that.

Tests the diff carries, in `cosmic/js_test.tl` (29 lines):
- `test_escape_literal_escapes_quotes` (4-7) changes its expectation from
  `\"` to `\u0022`.
- new: `escape_literal("`${alert(1)}`")` contains none of `` ` ``, `$`, `{`,
  `}` and equals `\u0060\u0024\u007balert(1)\u007d\u0060`.
- new: `escape_literal('");alert(1);//')` contains no `"` byte at all
  (the on*-attribute probe).
- keep `test_escape_literal_escapes_closing_script_tag` and
  `test_escape_literal_preserves_plain_text` as they are; add
  `escape_literal("\u{2028}") == "\\u2028"` so the line-terminator rule the
  doc claims is pinned.
