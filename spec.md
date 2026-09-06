## Evidence

`_tool/doc/init.tl`'s `parse` (infallible by type: `function(source: string, file_path: string): ModuleDoc`) calls `doc_signature.function_signatures`, which is fallible (`nil, err` on an `ast.parse` failure), inside an `if sigs then` and drops `err` — a module whose source fails to parse renders as a page with zero functions and no message, against AGENTS.md's "never silently discard errors" (PR cosmic#1774 review finding 2). Unreachable in the gate today because doc generation runs after `--check types`, which refuses a parse error first; reachable from `cosmic --docs` on an arbitrary path.

## Change

`_tool/doc/init.tl`: `parse` surfaces the failure — either by becoming `ModuleDoc | nil, string` (callers `parse_file`/`render_file` already return that shape, so they pass it up) or, if the infallible contract is kept deliberately, by recording the parse error on the `ModuleDoc` (a `parse_error: string` field the renderer prints as the page's first line). Pick the first unless a caller count makes it wider than a one-file change; say which in the PR body. `_tool/doc/init_test.tl` or `signature_test.tl`: a source that does not parse yields the error, not an empty function list.

## Non-goals

No change to what a parseable module renders.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

A test feeds an unparseable source through `_tool.doc`'s `parse` path and reads the parse error back, and `grep -n 'if sigs then' _tool/doc/init.tl` no longer names a branch that drops `err`.
