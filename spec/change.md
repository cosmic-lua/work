Two new files, two edited, one regenerated floor.

### `_tool/discovery.tl` — new

A module header saying what discovery is for: one walk answers what a
test file is and which cases it holds, so the lint, the compile seam
and the migration read one answer instead of three. Move `end_line_of`
here from `_cli/lint.tl:152-185`, body and comment unchanged — it is
the block-depth walk the case scan needs and it has no other caller.

The exported types and the one function:

```teal
local record Case
  name: string
  line: integer
  called_at: integer | nil
end

local enum Mode
  "none"
  "legacy"
  "runner"
  "mixed"
end

local record Discovery
  mode: Mode
  cases: {Case}
end

scan: function(file: string, content: string, lines: {string}): Discovery
```

`scan` does exactly this:

1. `tl.lex(content, file)`; on nothing, return `{mode = "none",
   cases = {}}`. `scan` does NOT check the path — classification is a
   fact about the CONTENT, and it is the lint that decides which paths
   it cares about. This is the one behavioural difference from the
   walk as it stands, and it is what lets the seam call `scan` on a
   file it is about to compile.
2. For each `local function <name>` whose `local` token is at column 1
   and whose `<name>` matches `^test_`, in source order: `line` is the
   `local` token's line, and `called_at` is the line of the first
   non-blank line after the definition's `end` when that line matches
   `^<name>%s*%(`, else nil. Source order is the case order; the list
   is never sorted.
3. `mode` is derived from the cases, never asserted separately: no
   cases → `"none"`; every case has a `called_at` → `"legacy"`; no case
   has one → `"runner"`; otherwise → `"mixed"`.

### `_tool/discovery_test.tl` — new

Legacy mode (every `test_*` called on the line after its `end`), using
`cosmic.check`, with a local helper that splits a source string into
lines and calls `scan` at a fixture path — no file is written. Cover:
each of the four modes from a source string; source order preserved
with three cases; `line` and `called_at` are the real line numbers;
a blank line and a comment line between an `end` and its call still
count as called; a helper (`local function make_db`) and an
`Example_*` are not cases; a `test_*` nested inside another function
(not at column 1) is not a case; `test_*` written inside a string or a
comment is not a case; nested `for`/`while`/`do`/`if`/`repeat` blocks
inside a case body do not confuse the `end` search; and a file with no
`local function` at all is `"none"` with an empty list.

### `_cli/lint.tl` — the rule reads the module

`local discovery = require("_tool.discovery")` in the alphabetical
require block. Delete `end_line_of` and the token walk inside
`check_call_after_define`; the rule keeps its exported name, its
signature `(file, content, lines)` and its doc comment's first
paragraphs, and becomes:

- return `{}` unless `file:match("_test%.tl$")` — the path scoping
  stays in the rule, where it already is;
- `local found = discovery.scan(file, content, lines)`;
- return `{}` unless `found.mode == "mixed"`;
- one diagnostic per case whose `called_at` is nil, at that case's
  `line`, column 1, rule name `call-after-define` unchanged.

The message gains the reason the rule now fires: the file is half
migrated — some `test_*` are self-called and some are not — so name
the uncalled function and say to pick one mode for the whole file,
keeping the existing clause about a failing run naming the function.
Extend the doc comment to say what the rule now permits and why:
`legacy` and `runner` are both whole answers to D29 and both lint
clean; `mixed` is the only shape that cannot be, because a reader
cannot tell which half is the mistake.

**The hazard this opens, stated so it is not discovered later.**
Until the compile seam lands (3IOCdHTM), a runner-mode file's cases
are defined and never called, so `--make test` runs the file and
executes no test. That is not silent — `_tool/testrun.tl:289` prints
each file's case count, so such a file reports `0 test functions` —
and the tree holds no runner-mode file today. Do not add a second rule
or a temporary guard for it; the seam is the fix and it is filed.

### `_cli/lint_test.tl` — one added test

The four existing `call-after-define` tests (`:202`, `:221`, `:234`,
`:247`) must pass **unchanged** — they are the regression net for the
extraction. Add `test_call_after_define_permits_a_whole_mode`: a
source with two `test_*` and neither self-called yields no
diagnostics, and the same source with one of the two self-called
yields exactly one, naming the uncalled function.

### The committed floor

`bin/cosmic --make coverage --baseline`, then commit
`.cosmic-coverage` — it gains a row for `_tool/discovery.tl`. Never
hand-edit it. If any other ratchet complains, run exactly the regen
command its failure message prints and commit the result.
