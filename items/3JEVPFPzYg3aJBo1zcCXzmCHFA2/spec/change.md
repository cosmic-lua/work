Add `cosmic/csv.tl` (new file), a pure-Teal module with no `cosmo.*`
dependency:

- `csv.parse(text: string, opts?: ParseOptions): {{string}} | nil,
  string` — splits `text` into rows of fields per RFC 4180 quoting:
  fields are comma-delimited (configurable `delimiter` in
  `ParseOptions`, default `,`), a field containing the delimiter, a
  double-quote, or a newline must be wrapped in `"`, and a literal `"`
  inside a quoted field is written as `""`. Row separator is `\r\n` or
  `\n` (accept either on read); a trailing unterminated quoted field or
  mismatched quote returns `nil, string` naming the byte offset (this
  module has no C call in play, so this is not `errno`-shaped — follow
  the same reasoning cosmopolitan's `cosmo.DecodeLua` uses for its own
  refusal-offset slot 3, per `/home/user/cosmopolitan/AGENTS.md`'s named
  exception; here it can ride in the message itself since there is no
  slot-3 convention for pure-Teal parsers in `cosmic/*`).
- `csv.stringify(rows: {{string}}, opts?: WriteOptions): string` —
  inverse: quotes a field exactly when it contains the delimiter, a
  quote, `\r`, or `\n`; writes `\r\n` between rows by default
  (`opts.line_ending` may override to `\n`).
- `ParseOptions` / `WriteOptions` records: `delimiter: string?` (default
  `,`), `WriteOptions.line_ending: string?` (default `\r\n`).
- Follow the honest-nil pattern from `AGENTS.md`'s Error Handling
  Patterns section: `parse` is `T | nil, string` (fallible value),
  `stringify` is infallible (bare `string` return — no malformed input
  is possible from a `{{string}}` Lua value).
- Module doc header in `cosmic/url.tl:1`'s style: one H1 line ("CSV
  encoding and decoding (RFC 4180)."), an `Example usage:` block.

Add `cosmic/csv_test.tl` (new file, `*_test.tl` runner-mode per
`AGENTS.md`'s "tests are enrolled by being defined" — top-level
`local function test_*`, no self-calling): round-trip tests
(`stringify` then `parse` recovers the original rows), quoting edge
cases (embedded delimiter, embedded quote, embedded newline, empty
field, empty row), a custom-delimiter case (e.g. `;`), and the malformed
cases (unterminated quote, quote not immediately followed by delimiter
or newline) asserting `nil, string`.

No `cosmic/csv_example.tl` is required — `cosmic/errno_test.tl` shows a
public module can ship without one (`ls cosmic/errno_example.tl` → not
found) — but add one if the builder finds the doc's runnable-example
convention (`cosmic --docs csv`) reads better with one; either way stays
under the 500-line file cap per module.

No other file changes: no registration list exists to update (see
Evidence), and `cosmic --make ci` (fmt, check, example, lint, coverage)
is the only gate.
