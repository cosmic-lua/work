Add one lint rule, `assert-justify`, to the module #1399 created, and
lift the justification-comment reader both rules need into the module
they both already require.

**1. `_tool/lint.tl`** — add the shared reader. Move
`_cli/lint.tl:56-64`'s `is_justified` here and give it the marker word
as a third parameter:

```teal
local function is_justified(lines: {string}, y: integer,
    marker: string): boolean
```

Body as it stands today, with the two hardcoded `"%-%- cast: %S"`
patterns built from `marker` instead (`"%-%- " .. marker .. ": %S"`,
and the same with the `^%s*` anchor for the line above). Export it
from the returned table beside `check_file_length`. Extend the module
header: it says the pure checks need "nothing but the file's lines",
which is exactly what this reader needs — say that the marker readers
for `-- cast:` and `-- assert:` live here for that reason, while the
lexer walks that find the sites stay in `_cli`.

**2. `_cli/lint.tl`** — delete the local `is_justified` and change its
one call site (`:77`) to `style.is_justified(lines, y, "cast")`. No
other change to this file, and no new require: `style` is already
bound at `:23`.

**3. `_cli/assert_lint.tl`** — add the rule beside `check_return_assert`:

```teal
local function check_assert_justification(file: string, content: string,
    lines: {string}): {Diagnostic}
```

- **Scope by path, first thing.** Return `{}` unless
  `file:match("^cosmic/")`, and return `{}` when the path matches
  `_test%.tl$` or `_example%.tl$`. Use `^cosmic/` and nothing else —
  `_cli/visibility.tl:25` scopes the same way, and the repo-relative
  paths `--make lint` walks are what the gate passes. Do NOT also
  match `/cosmic/`: the repository root directory is itself named
  `cosmic`, so that pattern would sweep the entire tree in an
  absolute-path invocation.
- **Find the sites token-exactly** via `tl.lex(content, file)`, the
  way `check_return_assert` already does in this module: an `assert`
  token whose `kind` is `identifier`, immediately followed by `(`, and
  whose PRECEDING token is neither `.` nor `:` — so `x.assert(v)` and
  `x:assert(v)` are not the global. One diagnostic per LINE, not per
  token: a line with two asserts takes one `-- assert:` comment, which
  is how `cast_lines` dedupes by `t.y` today.
- **Ask the shared reader** whether that line carries its
  justification: `style.is_justified(lines, y, "assert")`.
- The diagnostic: `rule = "assert-justify"`, `line` and `col` from the
  `assert` token, and a message in the voice of `cast-justify`'s —
  naming that a library `assert` throws, that D23 licenses it only for
  a `cosmo.*` return whose `| nil` is unreachable for the arguments
  passed, and that the licence needs a trailing `-- assert: <why the
  nil cannot occur>` (or one on the line above). It must contain the
  literal substrings `-- assert:` and `guide.lint`, which is what the
  test asserts on.
- Re-export it: add `check_assert_justification` to the
  `AssertLintModule` record and to `M`, beside `check_return_assert`.
- Extend the module header, which today describes only arity: say the
  module now holds both assert rules — the arity trap and the
  justification proviso.

**4. `_cli/lint.tl`, composition** — one require-free loop in
`lint_file`'s `path:match("%.tl$")` block, directly after the existing
`assert_lint.check_return_assert` loop:

```teal
for _, d in ipairs(assert_lint.check_assert_justification(path, content,
    lines)) do
  diagnostics[#diagnostics + 1] = d
end
```

plus the matching `check_assert_justification` field on the
`LintModule` record and entry in `M`, mirroring how
`check_return_assert` is re-exported.

**5. `_cli/assert_lint_test.tl`** — add `test_*` functions, each called
on the line after its `end`, per AGENTS.md. The fixture sources are
inline strings, as the file's existing cases are; the helper must pass
a `cosmic/`-prefixed path (the existing `diagnose` helper hardcodes
`"fixture.tl"`, so add a second helper rather than changing it — the
`return-assert` cases must keep firing on a non-`cosmic/` path). Cases:

- an unjustified `assert(v)` in a `cosmic/` path is flagged, at the
  right line, with `rule == "assert-justify"`;
- the same line carrying a trailing `-- assert: <reason>` is not;
- the same line with `-- assert: <reason>` on the line ABOVE is not;
- a bare `-- assert:` with no reason after it IS still flagged (the
  `%S` in the pattern is what demands one);
- the same unjustified `assert(v)` at a `_cli/` path is not flagged
  (scope), and at a `cosmic/..._test.tl` path is not flagged;
- `x.assert(v)` and `x:assert(v)` in a `cosmic/` path are not flagged;
- an `assert(v)` inside a double-quoted string is not flagged;
- an `assert(v)` inside a `[[ ]]` long bracket is not flagged — this
  is `cosmic/embed/init.tl:186`'s shape and the reason the rule is
  lexer-based;
- two asserts on one line yield ONE diagnostic.

**6. `_tool/lint_test.tl`** — add a `test_*` for the moved reader:
justified on the line, justified above, unjustified, and that the
marker discriminates (a `-- cast:` comment does not justify an
`"assert"` query, and the reverse).

**7. `docs/guides/lint.md`** — a `## assert-justify` section
immediately after `## cast-justify` (which ends at `:64`, before
`## call-after-define` at `:65`), following the shape of the sections
around it: what the rule catches, why the checker cannot, and the fix.
Point at D23 as the licence and at `## cast-justify` as the twin. Both
snippets go in ```text fences, NOT ```teal — `_build/snippets_test.tl`
compiles and format-checks every `teal` fence at full strictness, and
a licensed-assert fragment is not a compilable module.

**8. The coverage ratchet.** This adds no file, but it moves the
covered/total rows for `_cli/assert_lint.tl`, `_cli/lint.tl` and
`_tool/lint.tl`. If the coverage stage complains, run exactly the
regen command its failure message prints and commit the result; do not
weaken the gate any other way.
