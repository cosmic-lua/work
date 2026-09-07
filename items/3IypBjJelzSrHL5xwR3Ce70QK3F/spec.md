## Evidence

Two lints read comments as TEXT: `_cli/reads_lint.tl` (190 lines, 11 `match(`/`find(` sites, 0 `tl.lex`) scans a file's `--- reads:` header lines by pattern, and `_tool/lint.tl`'s `is_justified` (`:54-64`) reads a site's `-- cast:`/`-- assert:`/`-- throws:`/`-- exits:` marker by matching the line's text and the line above. The lexer already attaches every comment to the token that follows it: `cosmic/ast/node.tl:112` (`Parsed.tokens`, "the full token stream, comments and all") and `tl.Token.comments` (`o/_types/types_gen/tl.d.tl:35`, a `{Comment}` with `y`, `x`, `text`). `_cli/citations.tl` (319 lines, 8 pattern sites) reads MARKDOWN prose in `docs/design/`, which has no token stream; it is not in scope.

## Change

One comment reader over the token stream, `_tool/comments.tl`: `header(parsed)` returns the leading `---` block's lines (the doc comment before the first non-comment token) and `attached(parsed, y)` returns the comments on the token at line `y` and on the token that opens line `y` (the trailing marker and the line-above marker, the two placements `is_justified` accepts today). `_cli/reads_lint.tl` reads `reads:` from `header(...)`; `_tool/lint.tl`'s `is_justified` reads the marker from `attached(...)` — a `-- cast:` inside a string literal or a long comment no longer counts, which is the residue of «npTS_YYtP» that the lexer-based rules did not cover (they find the SITE token-exactly but read the MARKER by line text). Tests: `_cli/reads_lint_test.tl` and `_tool/lint_test.tl` keep their cases and each gains one: a `reads:` line inside a long string is not a declaration; a `-- cast: why` inside a string on the cast's line does not justify it.

## Non-goals

`_cli/citations.tl` stays a text scan (markdown); no new marker words.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`grep -c 'match(' _cli/reads_lint.tl` drops to the path-token parsing only, `_tool/lint.tl` has no line-text marker read, and the two new cases pass.
