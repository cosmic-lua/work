**What the count settled.** The item's first job was the tree-wide number, and
it is **136 `return nil` sites across 58 files** whose declared slot 1 does
not admit nil — out of 785 line-anchored `return nil` sites in 602 committed
`.tl` files (`git ls-files '*.tl'`, `.d.tl` excluded).

Re-measured at pull, by the token-exact detector this slice builds. An
indentation-based approximation at refinement said 116 in 48, and it was
wrong in BOTH directions, each for a reason a line-anchored regex cannot
avoid:

- it MISSED single-line `if not ok then return nil, err end`, because the
  line does not begin with `return` — 8 such sites in `_docs/publish.tl`
  alone;
- it over-counted anonymous `function` expressions bound to a field or a
  local (`setup = function(): any, string`), whose header no `^function`
  pattern matches, so their `nil` was charged to an enclosing named function
  — `_perf/bench/embed_bench.tl:164,168` sit under `: any, string`, which
  admits nil, and `cosmic/child/init.tl:411` sits under
  `start(...): Handle | nil, string`, likewise.

Both readings were hand-checked against the source before the number moved.
136 is the truer count, and the committed baseline is its record.

The class reaches public library source, not just tooling —
`cosmic/flags/parse.tl` 7, `cosmic/fs/find.tl` and `cosmic/zip.tl` among
them —
and the three kinds are all present: a `boolean, string` effect returning
`nil, err` where the house rule says `false, msg` (`_docs/publish.tl:190`); a
function whose doc comment already says `@return boolean|nil` while its
signature says `boolean` (`_eval/journal.tl:168`); and a function returning an
error string whose `nil` means success (`_perf/bench/embed_bench.tl:72`).

**So this lands as a ratcheted count, not a checker change.** 116 sites break
at once under a checker that refuses them, which is not a slice; a patch to
`3p/tl/tl_patch/` is the honest end state and belongs behind the sweep, filed
separately. Build it as the tree's existing cast ratchet, which is the same
shape: a counter in `_cli/`, a per-file floor in `_build/`, a test that holds
the count in both directions.

**1. `_cli/returns.tl` — the detector.** This module already parses declared
return lists token-exactly (`parse_list` returns one `admits_nil` boolean per
slot, `params_open` finds a signature's `(`), and it is 286 lines, 214 under
the cap. Add, and export, `nil_return_lines(content: string, file: string):
{integer}` — the lines holding a `return nil` whose innermost enclosing
function DEFINITION declares a slot 1 that does not admit nil. It mirrors
`_cli.lint`'s `cast_lines`, which is what `_build/casts.tl` counts. What it
needs beyond what is here:

- **Function nesting.** Walk tokens keeping a stack of open function
  definitions. Count block openers `function`, `do`, `if`, `record`, `enum`
  and `interface` as opening a block and `end` as closing one — `while`/`for`
  are covered by their own `do`, and `repeat` closes on `until`, not `end`.
  A `return nil` is attributed to the INNERMOST open definition, so an inner
  closure's nil is never charged to its outer function.
- **Definitions, not types.** A function TYPE (`f: function(x: string): T`)
  opens no block and has no `end`; only a definition is pushed. Discriminate
  on the token before `function`: a definition follows `local`, `=`, `,`,
  `(`, `return`, `then`, `do`, `else` or a statement boundary, never `:` or
  `|`, which put it in type position.

  **Corrected at review (this rule as written is wrong).** The token before
  `function` cannot decide this, because `{`, `<` and `,` each precede a
  definition in one context and a TYPE in another: `local t = {function()
  return 1 end}` against `local t: {function(): string}`, and `f(a,
  function() end)` against a return list `(): boolean | nil, function():
  integer`. Treating them all as definitions pushes a frame that no `end`
  ever pops, and the honest `return nil` inside the enclosing function is
  then charged to that frame — a FALSE POSITIVE on correct code, told to
  fix a signature that already says `| nil`. Reviewer reproduced three:
  `{function(): T}` and `Box<function(): T>` inside an honest body, and a
  function type after `,` in a return list.

  The discriminator must be STRUCTURAL — track whether the enclosing
  bracket was itself opened in type position — and the tree already solves
  exactly this: `cosmic/format/types.tl`'s `mark_function_type` /
  `mark_return_list` (~lines 100-150), whose comment names the same failure
  and cites a real file with the shape (`_types/cosmo/lsqlite3.d.tl`'s
  `config`, returning `function | nil`). Reuse that reasoning rather than
  re-deriving a token blacklist.

  The fixture must PIN this: the current `types` case passes under a
  detector with the type-position guard removed, so it guarantees nothing.
  Every new fixture case must be one that FAILS when the rule it names is
  broken.
- **`return nil` in slot 1.** The token after `return` is `nil`; what follows
  it does not matter, so `return nil, err` counts exactly as `return nil`
  does when slot 1 is declared non-nil.
- A function with NO declared return type is not in the class and is skipped.

**2. `_build/nil_returns.tl`** — modeled on `_build/casts.tl` (143 lines),
line for line: the same `TREES` list, the same `count(root): {string: integer}`
walk skipping `testdata/` and `.d.tl`, the same `baseline()` read through
`_tool.floor`, and the same `main(...)` behind `proc.is_main()` accepting only
`--baseline` and printing what it wrote. `BASELINE` is
`"_build/nil_returns_baseline.tl"`.

**3. `_build/nil_returns_baseline.tl`** — generated, never hand-edited:

```
bin/cosmic --make run _build/nil_returns.tl --baseline
```

**4. `_build/nil_returns_test.tl`** — modeled on `_build/casts_test.tl` (102
lines), with its `--- reads:` header lines for the same trees. Two tests:

- the ratchet, in both directions, exactly as the cast one reads it: a file
  over its floor fails, and a file UNDER it fails too, naming the regen
  command, so the floor always states what the tree carries. Unlike the cast
  ratchet, print the offending LINE NUMBERS for a file that grew —
  `nil_return_lines` returns them, and a ratchet that says only "3 (baseline
  2)" makes the author find the site themselves.
- a fixture test over a constructed tree, pinning the detector's rules: a
  `: string` returning nil counts; a `: string | nil` returning nil does not;
  a `: boolean, string` returning `nil, err` counts; an inner closure's
  `return nil` is charged to the closure and not to an outer function whose
  own return admits nil; a `return nil` quoted inside a string counts for
  nothing; and `testdata/` is skipped.
