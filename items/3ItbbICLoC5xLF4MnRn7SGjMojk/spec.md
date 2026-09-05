## Change

Ready when: the D10 amendment (`pmsp_heru`'s child) is merged —
`git log --oneline -1 -- docs/decisions/d10-right-to-break.md` shows
its commit — and `_tool/surface.tl` exists on main (sibling item).

Three parts, one PR: the surface baseline moves from module level to
name level and shards per module; a `cosmic/_gone/` tree holds the
wrapper for every name that left; the gate refuses a name that left
without one.

**Baseline.** `_build/public_surface_baseline.tl` (56 module lines
today) is replaced by `_build/surface/<module>.tl`, one file per
public module — 56 files, together carrying every key `_tool/surface`
extracts (measured 1214 record fields across the public modules and
their shards, 771 function-typed, with the prototype extractor over
HEAD; the lexer-based one will differ slightly). Each file is a
`_tool/floor` literal (`_tool/floor.tl:83-86`: `read`/`write` over
`cosmic.literal`, keyed entries with any literal value), entries
`["cosmic.string.StringModule.truncate"] = "function(s: string, width: integer, suffix?: string): string"`
sorted by key. Per-module files because a single file would exceed the
500-line cap, and because a break touches one module's file — the
PR diff shows the names that moved and parallel sessions rarely
collide (G9's stated reason for a per-PR surface ratchet). `_build/
public_surface.tl` (150 lines) keeps its `--baseline` entry point and
writes the shards; its `modules(root)` stays for the module-level
view. `_build/public_surface_test.tl` (83 lines) keeps its
module-level assertions and gains the name-level gate below.

**Gone tree.** `cosmic/_gone/<module path>.tl` — `cosmic/_gone/string.tl`
for `cosmic.string`, `cosmic/_gone/fs.tl` for `cosmic.fs` (shards
fold into their module, as the surface does), `cosmic/_gone/uuid.tl`
for a module that no longer exists. Internal by position (underscore),
embedded in the binary as source like `cosmic/_fields.tl` is
(`unzip -l o/bin/cosmic | grep '\.tl/cosmic/_'` lists five today),
never required by anything: it is data the ratchet and `--upgrade`
read as Teal. Its grammar, all of it:

```
--- What left cosmic.string, each as the call that replaces it.
local string = require("cosmic.string")
local check = require("cosmic.check")

--- gone 2026-09-06: renamed; same arguments, same result
local function truncate(s: string, width: integer, suffix?: string): string
  return string.ellipsize(s, width, suffix)
end

--- gone 2026-09-06: same name, new type — nil when s holds a NUL byte,
--- which no argv can carry; must() keeps old call sites infallible
local function shell_quote(s: string): string
  return check.must(string.shell_quote(s))
end

-- gone 2026-09-06 Options.pretty: a non-nil indent means pretty;
-- {pretty = true} is {indent = "  "} (the old default was two spaces)
```

- A wrapper is a `local function` whose name is the field that left,
  whose parameter and return types are the baseline's type string for
  that key (so the gate can check it), and whose body is exactly one
  `return <expression>` statement (so the inliner is substitution).
  Its first doc line is `gone YYYY-MM-DD: <one sentence>`.
- A `-- gone YYYY-MM-DD <Record>.<field>: <sentence>` line covers a
  record field or enum member, and a function with no replacement.
- Every `cosmic/_gone/<m>.tl` has a `cosmic/_gone/<m>_test.tl` beside
  it whose cases call each wrapper: that test is the equivalence
  claim, run by `--make test` like any other. Both files get rows in
  `.cosmic-coverage` by hand, as the coverage rules require
  (`_tool/coverage/newrows.tl` prints them).

**Gate**, in `_build/public_surface_test.tl`: extract the tree's
surface with `_tool/surface`, read the shards, and for every key in
the baseline that is absent or retyped in the tree require, in
`cosmic/_gone/<module>.tl`, a wrapper named for the field whose
declared type (lexed the same way) equals the baseline's string, or a
`-- gone` line naming `<Record>.<field>`; require the test file to
exist when the gone file does; require every wrapper body to be one
`return`. Each failure names the key, the file it expects, and the
two-line remedy. Added keys fail exactly as today's added modules do:
"the surface grows only deliberately — run `bin/cosmic --make run
_build/public_surface.tl --baseline`, commit it, and say why". A
`retyped` key whose new type merely widens a PARAMETER to admit nil is
not a break and passes without a wrapper; every other retype is one.

Cost to a breaker, measured against the last three weeks of main:
22 wrappers and 8 `-- gone` lines would have been written for the 30
public-name changes the census found (2 functions removed, 8 fields
removed, 20 retypings — see `55xyILjS`).

Sweep: the existing `find-needle`/visibility lint already refuses a
`require("cosmic._gone.x")` from outside `cosmic/`; confirm with a
probe file under `_make/testdata/` during the PR and paste the
refusal into the PR description.

## Non-goals

No verb reads the gone tree here; `--upgrade` does. No retirement
rule for wrappers (see the container). AGENTS.md gains one bullet
under conventions — "a public name leaves with its wrapper in
`cosmic/_gone/`; the surface ratchet enforces it" — and nothing more;
the grammar above lives in the gone tree's own header doc.
