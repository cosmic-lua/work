Touch exactly three files: `_cli/citations.tl` (new),
`_cli/citations_test.tl` (new), `_cli/lint.tl`. No document changes.

**1. `_cli/citations.tl`** — a new check module beside the other
lexer-free checks (`_cli/returns.tl` 283 lines, `_cli/pattern_args.tl`
255, `_cli/reads_lint.tl` 80; `wc -l` at `e0d217dd`), exporting

```teal
check_citations(file: string, lines: {string}): {Diagnostic}
```

with `Diagnostic` the record `_tool/lint.tl:17` defines (`file`, `line`,
`col`, `rule`, `message`) and `rule = "doc-citation"` on every finding.

One pass over `lines`, tracking fenced-block state (a line whose first
non-space characters are ``` or ~~~ toggles it), doing:

- **Snapshot detection.** Outside a fence, a line matching
  ``^Measured against `(%x%x%x%x%x%x%x+)` `` marks the document a
  snapshot. The fence guard is required, not decorative: a document that
  QUOTES that sentence inside a code block — this spec does — must not
  be read as a snapshot.
- **Outside a fence: inline citations.** For each backticked span
  (`` line:gmatch("`([^`]+)`") ``), the WHOLE span must match
  `^([%w_%-%./]+%.[%w_%-]+):(%d+)$` or the same with `-(%d+)` appended.
  Requiring the whole span is what keeps the count at the 37 measured
  above: a span like `` `grep -c '^<file>\t' docs/…tsv` `` contains a
  path but is not a citation.
- **Inside a fence: the header shape.** Only the block's FIRST content
  line is examined, and only against `^%-%- ([%w_%-%./]+):(%d+)$`. When
  it matches, the block's next non-empty line is the quote.

For each citation: skip it when the path begins `o/`. Otherwise read the
cited file once per path (a table keyed by path, local to the call, so a
document citing one file 13 times reads it once) and report:

- the path is not a file → *"`<citation>` names no file"*, naming the
  document and the citation.
- HEAD document, the line (or a range's upper end) is past the file's
  last line → *"`<citation>` is past end of file (`<path>` has N lines)"*.
- HEAD document, fenced shape, the quote and the source line at
  `<line>` differ after both are stripped of leading and trailing
  whitespace → a message carrying BOTH, so the fix is visible without
  opening either file.

A range (`AGENTS.md:180-184`) is checked for both ends being within the
file and nothing more. Asserting what a prose range CONTAINS needs the
document to state it, which is a different and larger design.

Multi-line quotes match on the FIRST non-empty line only: the nil-flow
blocks quote 2-6 lines with elisions, so a whole-block match is not
achievable, and the first line is what pins the position.

Every diagnostic's `message` opens `"%s:%d: "` with the document and its
line, matching `_cli/pattern_args.tl:123` and `_cli/reads_lint.tl:59`.

**2. `_cli/lint.tl`** — a new `%.md$` branch in `lint_file` (the
function at line 345 today) beside the existing `%.tl$` one, plus the
`require("_cli.citations")` at the top: six lines in all. Do NOT add
`check_citations` to the `LintModule` record or to `M` —
`_cli/citations_test.tl` requires the module directly, so the export
would have no caller. `wc -l _cli/lint.tl` reports **457** at
`e0d217dd`, 43 lines under the 500-line cap.

**3. `_cli/citations_test.tl`** — fixtures built under `TEST_TMPDIR`,
with the test chdir'ing in and restoring the old cwd afterwards
(`fs.cwd` / `fs.set_cwd` — corrected at implementation time, this line
first named a `fs.chdir` that does not exist;
`cosmic/fs/init_test.tl:211`'s
`test_getcwd_and_chdir` is the worked example), because cited paths
resolve relative to cwd. Each `test_*` is called on the line after its
`end`, per AGENTS.md. Cover, one test each:

- a resolving inline citation → no diagnostic
- an inline citation past end-of-file → one diagnostic
- an inline citation naming a path that is not a file → one diagnostic
- an `o/`-prefixed citation into a path that does not exist → skipped
- a range with both ends inside the file → no diagnostic
- a range whose upper end is past end-of-file → one diagnostic
- a fenced block whose quote matches → no diagnostic
- a fenced block whose quote does not match → one diagnostic naming both
- a snapshot document (carrying the `Measured against` line) whose
  fenced quote does not match and whose inline line is past
  end-of-file → no diagnostic
- a snapshot document citing a path that is not a file → one diagnostic
- a document whose only `Measured against` line is INSIDE a fenced block
  → treated as a HEAD document, so its bad quote is still a diagnostic
