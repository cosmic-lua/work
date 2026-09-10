## Change

Add `_tool/surface_scan.tl` and `_tool/surface_scan_test.tl`, and touch no
other product file. Export a fallible
`scan(source: string, path: string): {Member} | nil, string`; each `Member`
carries declaration kind, record/enum name, member name, canonical type, and
source line/column. Return an error, never a partial list, for lexer errors,
unbalanced declarations, or ambiguous syntax.

Use `tl.lex`. A runtime probe against current main produced `record` and `enum`
as `identifier` tokens, `function`/`end` as `keyword`, comments outside `.tk`,
and lexer errors alongside a nonempty token list. Do not test `if not tokens`
for failure. Distinguish declaration bodies from function types. Consume types
across physical lines with `_cli.returns`' exported `parse_type`, `parse_list`,
and `skip_balanced` token-span helpers; do not create another Teal type grammar.
Canonical type text joins the selected tokens with one space. Enum values are
decoded to semantic bytes and percent-encoded reversibly for a key segment;
their stored type is `enum`.

The scanner must tolerate valid non-member syntax inside a record without
emitting it. Consume and skip nested `type Alias = ...` declarations, direct
array headers such as `{string}`, and nested `interface ... end` declarations,
then continue scanning later fields. For a typed field followed by
`= macroexp ... end`, emit the field and its declared type, skip the initializer
body, and continue. These are syntax-tolerance rules, not new surface kinds;
unknown or malformed constructs still fail atomically as ambiguous syntax.

Tests cover top-level and nested records/enums, function-typed and multiline
fields, balanced generics/tables/tuples, trailing comments, string-literal
spellings, malformed lexing, missing `end`, and locations. Add before/after
field regressions for aliases, direct array headers, nested interfaces, and
macroexp initializers, including the existing Cosmic spellings named by the
review. Keep the combined change at or below 500 lines; bounce rather than
adding another module or surface kind.

## Non-goals

No filesystem/module visibility, shard ownership, surface keys, diff/render,
ZIP reading, CLI wiring, emitted alias/interface/array-header/initializer
members, alias target interpretation, or semantic type equivalence.
