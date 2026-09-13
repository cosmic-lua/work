Add a new pure lint rule, `reads-declaration`, that flags an
undeclared `fs.glob()` call in a `*_test.tl` file, and wire it into the
existing lint composition — no new CLI surface, no new verb.

1. **New file `_cli/reads_lint.tl`** (mirrors the existing
   `_cli/pattern_args.tl` / `_cli/returns.tl` / `_cli/visibility.tl`
   shape: a small module hosting one family of checks, required into
   `_cli/lint.tl`'s composition). It requires `_make.imports` (for
   `reads_scan`, already public) and the `Diagnostic` type from
   `_tool.lint`, and exports:

   ```
   check_reads_declaration: function(file: string, content: string,
     lines: {string}): {Diagnostic}
   ```

   Logic:
   - Return `{}` unless `file:match("_test%.tl$")`.
   - Return `{}` if `file` is in a local `ALLOWLIST` table (see below).
   - Return `{}` if `#imports.reads_scan(content) > 0` (the file
     already declares at least one read).
   - Otherwise, for every line matching the pattern `fs%.glob%s*%(`,
     append a `Diagnostic` with `rule = "reads-declaration"` and a
     message naming the mechanism and the fix, e.g.: `"%s:%d: fs.glob()
     enumerates files with no '--- reads:' declaration; a static import
     scan can't see what it finds at runtime, so this test's cached
     PASS never re-runs when those files change — add '--- reads:
     <dir>' naming what the glob covers (see _make/imports.tl)."`
   - `ALLOWLIST` starts with exactly one entry —
     `["cosmic/fs/glob_test.tl"] = true` — commented the same way
     `COSMO_REQUIRE_ALLOWLIST` in `_cli/lint.tl` comments its entries
     (this file tests `fs.glob()` itself against a `TEST_TMPDIR`
     fixture; nothing in it depends on the project tree).

2. **New file `_cli/reads_lint_test.tl`** (mirrors
   `_cli/returns_test.tl`'s standalone-test-file shape). Test cases,
   each a `test_*` function called immediately after its own
   definition per AGENTS.md:
   - a `*_test.tl` fixture string containing `fs.glob(DIR, "*.tl")` and
     no `--- reads:` header → one diagnostic, `rule ==
     "reads-declaration"`.
   - the same fixture with a `--- reads: some/dir` header line → zero
     diagnostics.
   - the same fixture named `cosmic/fs/glob_test.tl` (the allowlisted
     path) and no header → zero diagnostics.
   - a non-`_test.tl` file (e.g. `cosmic/fs/find.tl`) containing
     `fs.glob(` → zero diagnostics (scope is test files only).
   - a `_test.tl` fixture calling `fs.find(...)` (not `fs.glob`), no
     header → zero diagnostics (this slice's trigger is `fs.glob`
     only — see Non-goals).

3. **Wire into `_cli/lint.tl`** (current length 448/500 lines;
   headroom 52 — this adds roughly 6 lines, well inside it):
   - add `local reads_lint = require("_cli.reads_lint")` beside the
     other check-module requires (`pattern_args`, `returns`,
     `style`, `visibility`).
   - inside `lint_file`'s `if path:match("%.tl$") then` block, add a
     loop over `reads_lint.check_reads_declaration(path, content,
     lines)` appending into `diagnostics`, alongside the existing
     `check_find_needle` / `check_nil_declaration` / etc. loops.
   - add `check_reads_declaration: function(file: string, content:
     string, lines: {string}): {Diagnostic}` to the `LintModule`
     record and `check_reads_declaration = reads_lint.check_reads_declaration`
     to the `M` table, matching how `check_fallible_returns` (from
     `_cli/returns.tl`) and `check_shard_require`-equivalent entries
     are already re-exported through `_cli.lint`.

4. **`_perf/perf_test.tl`'s header needs NO code change** — the
   one-file fix the finding asked for (`--- reads: _perf/bench` on line
   1) already landed in commit `6831dcc7` ("fix: replace 51 from-any
   casts in _perf/bench with is guards", the exact PR the finding's
   Evidence section describes) and is present in the tree today. This
   slice's job is purely to make that fix load-bearing: prove via
   Acceptance that removing it now fails the new lint, where today it
   does not fail anything.

```facts
$ wc -l < _perf/perf_test.tl
75
$ grep -c '^--- reads:' _perf/perf_test.tl
1
$ head -1 _perf/perf_test.tl
--- reads: _perf/bench
$ wc -l < _cli/lint.tl
448
$ wc -l < _cli/lint_test.tl
436
$ grep -rl 'fs\.glob(' --include='*_test.tl' . | grep -v '/o/'
./cosmic/fs/glob_test.tl
./_perf/perf_test.tl
$ grep -c '^--- reads:' cosmic/fs/glob_test.tl
0
$ grep -n 'rule = "' _cli/lint.tl _cli/pattern_args.tl _cli/returns.tl _cli/visibility.tl _tool/lint.tl | wc -l
9
$ o/bin/cosmic --check lint _perf/perf_test.tl
Style check passed: _perf/perf_test.tl
$ sed '1d' _perf/perf_test.tl > /tmp/perf_test_no_header_test.tl && o/bin/cosmic --check lint /tmp/perf_test_no_header_test.tl
Style check passed: /tmp/perf_test_no_header_test.tl
```
The last two commands are the regression baseline: TODAY, with the
header removed, `--check lint` still reports a clean pass — proving the
current lint has no rule that would catch the exact bug this item is
about. After this slice lands, the same "strip the header, lint the
file" sequence must fail (see Acceptance).
