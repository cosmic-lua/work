# cosmic.csv: encode/decode module (first slice of #500's remaining checklist)

## Goal

Issue #500 ("§4.1: add missing battery modules") is an umbrella/tracking
issue that has already been largely worked off the tree since it was
filed — its own body (last updated 2026-08-15) checks off `cosmic.log`,
`cosmic.cli` (landed as `cosmic.flags`), HMAC (landed in `cosmic.hash`),
`cosmic.table` (landed as `cosmic.deep`), and `cosmic.ansi`. What is
left, as the issue itself states, is not one module but four
independent ones with different shapes and different blockers:

- `cosmic.csv` / `cosmic.toml` — pure Teal, no C dependency, no blocker
- `cosmic.httpd` — a thin wrap of redbean's `ParseHttpMessage`/
  `GetHttpHeader` C, sequenced as "Wave 3"
- `cosmic.tls` — blocked on cosmopolitan-side work (see
  cosmic-lua/cosmopolitan#143, "expose mbedTLS `wrap_client`/
  `wrap_server`" — that binding does not exist yet; confirmed below)
- a P3 tail (templating, MIME map, WebSocket, duration/semver) — of
  which templating has already landed as `cosmic/template/` and is
  stale in the issue's own checklist

Shoving all four into one item would violate the spec bar's one-Change
rule and the ~400-line sizing smell. This spec scopes only the smallest,
unblocked, independent piece: **`cosmic.csv`** — encode and decode for
RFC 4180-shaped CSV, the first of the two pure-Teal modules the issue's
own "Fix" note names as "what's left of Wave 2." `cosmic.toml`,
`cosmic.httpd`, and `cosmic.tls` are each their own follow-on items (see
Non-goals), not designed here.

## Evidence

Issue #500 body (fetched 2026-09-12 via `issue_read`), current checklist
state:

```
- [ ] cosmic.httpd (P1)
- [x] cosmic.log (P1) — cosmic/log.tl
- [x] cosmic.cli (P1) — landed as cosmic.flags
- [x] HMAC-SHA256 + constant-time compare (P1) — cosmic/hash.tl
- [x] cosmic.table (P2) — landed as cosmic.deep
- [ ] cosmic.csv / cosmic.toml (P2) — still absent
- [x] cosmic.ansi (P2) — cosmic/ansi.tl
- [ ] cosmic.tls (P2) — needs the mbedTLS wrap, U4 (cosmopolitan#143)
- [ ] P3 tail: templating, MIME map, WebSocket, duration/semver
```

Confirmed against the current tree (2026-09-12, `main` at the fetched
`origin/main` tip):

```
$ ls cosmic/csv.tl cosmic/csv
ls: cannot access 'cosmic/csv.tl': No such file or directory
ls: cannot access 'cosmic/csv': No such file or directory
$ ls cosmic/toml.tl cosmic/toml
ls: cannot access 'cosmic/toml.tl': No such file or directory
ls: cannot access 'cosmic/toml': No such file or directory
$ ls cosmic/httpd.tl cosmic/httpd cosmic/tls.tl cosmic/tls
(all four: No such file or directory)
```

but the P3 tail's "templating" line is stale — it already landed:

```
$ ls cosmic/template/
codegen.tl codegen_test.tl init.tl init_test.tl lex.tl parse.tl parse_test.tl types.tl testdata
```

No MIME map, WebSocket, semver, or duration-formatting module exists
either (`grep -rli websocket cosmic/*.tl cosmic/*/*.tl`, `grep -rli
semver cosmic/*.tl`, `grep -rn mime_type cosmic/*.tl` — all empty), so
those remain open too, each its own future slice.

No design decision governs a new module's shape or registration:
`AGENTS.md:87` states "position is the manifest: a module is public API
exactly when it is `cosmic.<name>` with no `_`", and
`_build/public_surface.tl` derives the public module list purely by
walking `cosmic/*.tl` and `cosmic/*/init.tl` — a new `cosmic/csv.tl`
needs no registration anywhere (no index, no list to edit). No board
item currently tracks `cosmic.csv` or `cosmic.toml`
(`bin/gitboard find "cosmic.csv"` → 0 hits, `bin/gitboard find
"cosmic.toml"` → 0 hits) and no `docs/decisions/*.md` addresses CSV,
TOML, or module scope for this checklist.

Reference for module scale and doc-header convention — a comparably
small, self-contained pure-Teal encode/decode module that landed as one
piece:

```
$ wc -l cosmic/tar.tl cosmic/tar_test.tl cosmic/tar_example.tl
  271 cosmic/tar.tl
  268 cosmic/tar_test.tl
   45 cosmic/tar_example.tl
  584 total
```

`cosmic/url.tl:1-16` shows the header-doc convention every public
module follows (an H1 one-liner used verbatim by `cosmic --docs`,
`Example usage:` block, then the functions).

## Change

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

## Non-goals

- `cosmic.toml` is not designed or touched here — it is the sibling
  "and" the spec bar's sizing rule says to cut out; file it as its own
  item once this one lands, so the two modules land as file-disjoint
  siblings.
- `cosmic.httpd` and `cosmic.tls` are not touched — `httpd` needs its
  own scoping pass around what "thin-wrap redbean's HTTP C" means for a
  Teal binding surface, and `tls` is blocked upstream (see Evidence).
- No CSV dialect beyond RFC 4180 (no Excel-specific quirks, no
  configurable quote character, no comment-line skipping, no header-row
  helpers like `csv.parse_with_header`) — those are extensions a later
  item can add once the base module has users.
- No streaming/large-file API (`csv.parse_file` reading incrementally)
  — `parse`/`stringify` operate on an in-memory string, matching
  `cosmic.json`'s and `cosmic.tar`'s existing shape.

## Access

- `cosmic-lua/cosmic` (read+write): the only repo this change touches.

## Acceptance

- `bin/cosmic --make ci` ends `ci: PASS`.
- `bin/cosmic --docs csv` prints the new module's reference, derived
  automatically from the doc header (no manual step).
- `bin/cosmic --make test cosmic/csv_test.tl` passes, covering the
  round-trip and malformed-input cases named in `## Change`.
