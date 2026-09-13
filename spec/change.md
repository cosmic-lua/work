Five hand-edited files plus one regenerated floor. **No `cosmic/**`
source is touched** — see Evidence.

### `_tool/lint.tl` — the scope predicate joins the marker reader

Move `is_library_source` here from `_cli/assert_lint.tl`, body
unchanged (`file:match("^cosmic/")` and not `_test%.tl$` /
`_example%.tl$`), keeping its doc comment including the paragraph on
why `/cosmic/` is not matched. Export it beside `is_justified`, and
extend the module header's paragraph about the shared marker reader to
say the library-source predicate is shared for the same reason: two
rules ask the same question about a path and a second copy is drift
waiting to happen. Nothing else in this file moves — not
`check_file_length`, not `DEFAULT_FILE_LINES`, not `is_justified`.

### `_cli/assert_lint.tl` — use the shared predicate

Delete the local `is_library_source` definition and call
`style.is_library_source(file)` at its one call site in
`check_assert_justification`. `style` is already required at the top.
No other change: `check_return_assert`, the module header, the
`AssertLintModule` record and `M` all stay exactly as they are.

### `_cli/throw_lint.tl` — new, the rule

A module header stating what D30 licenses and why a lexer walk rather
than a grep (name `process_error(` as the concrete false positive).
One exported function:

```teal
check_throw_justification: function(file: string, content: string,
  lines: {string}): {Diagnostic}
```

Rule name in every diagnostic: `throw-justify`. Behaviour, in order:

1. Return `{}` unless `style.is_library_source(file)`.
2. Return `{}` for exactly `cosmic/check.tl` and `cosmic/rand.tl` —
   module-level exemptions recorded in D23 and D22, which is why those
   two carry no per-site comments. Match the path exactly; no prefix
   or pattern match.
3. `tl.lex(content, file)`; return `{}` when it yields nothing, the
   way `check_assert_justification` does.
4. Walk the tokens. A site is either:
   - a **throw**: an identifier token `error`, not preceded by `.` or
     `:`, followed by `(`. Its marker is `throws`.
   - an **exit**: an identifier token `exit` preceded by `.`, which is
     preceded by an identifier token `os`, and followed by `(`. Its
     marker is `exits`.
5. Dedupe per (line, marker), not per line — one comment covers
   however many sites of the same kind share a line, the way one
   `-- cast:` covers a line's casts.
6. For each surviving site, `style.is_justified(lines, y, marker)`.
   When it is false, emit a `Diagnostic` with `rule = "throw-justify"`,
   the site's line and column, and a message that names **the marker
   that site needs** (`-- throws:` for a throw, `-- exits:` for an
   exit), says a `cosmic.*` module may throw or exit only where no
   caller could receive the value, and ends by pointing at
   `cosmic --docs guide.lint` — the same three parts
   `assert-justify`'s message has.

The marker is chosen by site kind and the other marker does not
satisfy it: `-- exits:` on an `error(` line is a miss, and so is the
reverse. That is D30's grammar, and stating it loosely would let the
two drift into interchangeable noise.

### `_cli/throw_lint_test.tl` — new

Legacy mode (every `test_*` called on the line after its `end`), using
`cosmic.check`, following `_cli/assert_lint_test.tl:107-114`'s helper shape: a
local helper that splits a source string into lines and calls
`check_throw_justification` at a chosen path. Fixture paths are
strings, so no file is written. The tests:

- an unjustified `error(` in a library path is flagged once, with
  `rule == "throw-justify"`, the right line, and a message containing
  `-- throws:` and `guide.lint`;
- an unjustified `os.exit(` likewise, with `-- exits:` in the message;
- a trailing `-- throws: <reason>` justifies, and so does one on the
  line above;
- a bare `-- throws:` with no reason after it does NOT justify (the
  `%S` in `is_justified`);
- the WRONG marker does not justify — `-- exits:` on an `error(` line
  is still flagged, and `-- throws:` on an `os.exit(` line is still
  flagged;
- `error` reached through a field or method (`x.error(...)`,
  `t:error(...)`) is not a site, and neither is `process_error(...)`;
- `error` and `os.exit` inside a string constant or a comment are not
  sites;
- a test path (`cosmic/foo_test.tl`), an example path
  (`cosmic/foo_example.tl`) and a path outside `cosmic/`
  (`_cli/foo.tl`) all yield no diagnostics;
- `cosmic/check.tl` and `cosmic/rand.tl` yield no diagnostics for an
  unjustified site;
- two unjustified `error(` calls on one line yield ONE diagnostic, and
  an `error(` and an `os.exit(` on one line yield TWO.

### `_cli/lint.tl` — wire it in

`local throw_lint = require("_cli.throw_lint")` in the alphabetical
require block; a `for _, d in ipairs(throw_lint.check_throw_justification(path, content, lines)) do`
block beside the `assert_lint.check_assert_justification` one inside
the `path:match("%.tl$")` arm; the matching field on the `LintModule`
record and entry in `M`, both named `check_throw_justification`.
Nothing else in this file moves.

### `docs/guides/lint.md` — one section

`## throw-justify`, placed alphabetically between `## return-assert`
and `## visibility`. State the rule (a `cosmic.*` module may throw or
exit only where no caller could receive the value), the three shapes
D30 licenses in one line each, the two markers and which site kind
takes which, the trailing-or-line-above acceptance, and the two
module-level exemptions. Link D30 the way the neighbouring sections
link their records.

### The committed floor

`bin/cosmic --make coverage --baseline`, then commit
`.cosmic-coverage` — it gains a row for `_cli/throw_lint.tl`. Never
hand-edit it. If any other ratchet complains, run exactly the regen
command its failure message prints and commit the result; that is in
scope and is the only sanctioned way to move a floor.
