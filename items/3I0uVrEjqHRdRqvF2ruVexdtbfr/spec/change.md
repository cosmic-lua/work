**Root cause, confirmed by direct reproduction (not inferred):**
`_tool/coverage/report.tl`'s `normalize()` has two structurally similar
branches that map a collector chunk source back to a repo `.tl` file.
For a chunk loaded from inside a **built cosmic artifact's embedded
zip** (`@/zip/<module>.lua` — recorded whenever coverage-instrumented
code runs from a packaged binary rather than directly from the tree,
e.g. via `cosmic/script_test.tl`, which builds and execs binaries), the
branch resolves the correct **display** path (the `.tl` source) but
returns the **parse** path as the raw zip chunk string itself:

```
local zipped = p:match("^/zip/(.+)%.lua$")
if zipped then
  for _, source in ipairs({zipped .. ".tl", zipped .. "/init.tl"}) do
    if not is_excluded(source) and fs.is_file(source) then
      return source, p        -- BUG: p is "/zip/cosmic/fs/octal.lua"
    end
  end
  return nil
end
```

`analyze()` later does `fs.read(entry.parse)` and feeds the bytes to
`cov_lines.executable_lines()` (which calls `tl.lex`/`tl.parse_program`
and needs real Teal/Lua **text**). But `/zip/<module>.lua` inside a
running cosmic binary is **precompiled Lua bytecode**, not source text
(confirmed below) — or simply absent, depending on which binary is doing
the reading. Either way, static executable-line analysis fails, and
`analyze()`'s documented fallback ("the line universe is the statically
derived executable lines unioned with the lines actually hit") silently
degrades to **hits-only**, since the static half came back empty. The
reported "total" becomes however many *distinct lines happened to be
hit* under that one chunk identity — not the file's real executable-line
count.

Because `report.compute()`'s `merge_hits` sets `entry.parse` only on
the **first** `.cov` file seen for a given display path (iterating an
unordered directory scan across hundreds of parallel test-runner `.cov`
files), whichever chunk identity — the readable `o/<path>.lua` staged
copy, or the broken `/zip/<path>.lua` artifact copy — wins the race
determines whether a file's reported total is right or silently
collapsed. That race is exactly what makes the same `.tl` source
resolve to a different total-line count "depending on the measuring
environment": it depends on directory-scan order across a swarm of
`.cov` files from parallel subprocesses, which is not stable across
machines or runs.

`cosmic/fs/octal.tl` is the file that exposed it because it is a
2-line-body function whose only *other* executable lines are two
module-boilerplate lines (`local M = {...}` and `return M`) that never
register as "hit" under **any** chunk identity in the current test
suite (see Non-goals) — so when the bug's hits-only fallback fires, the
collapsed total (2) looks like a clean 100%-covered small file instead
of a visibly broken number, and nobody caught it.

**The fix:** in `_tool/coverage/report.tl`'s `normalize()`, in the
`/zip/` branch, return the already-resolved `.tl` source as the parse
target too, instead of the opaque zip chunk string:

```
      return source, source
```

(one line, the `for` loop just above it already guarantees `source` is
`fs.is_file`-readable Teal text — that's strictly better input for
`cov_lines.executable_lines` than the zip chunk path ever was, and it
makes the result **independent of merge order** by construction: no
matter which `.cov` file's chunk creates the entry first, `parse` is now
always the same real `.tl` path.)

Add a regression test to `_tool/coverage/report_test.tl`. The existing
`test_normalize_maps_embedded_directory_modules` (lines 72-78) already
covers `/zip/` chunk normalization but only asserts the first return
value (`display`); it never checks `parse`, which is exactly the blind
spot that let this ship. Extend it (or add a sibling test) to assert
the second return value too, e.g.:

```
local _, parse = report.normalize("@/zip/cosmic/url.lua", "")
assert(parse == "cosmic/url.tl", "got: " .. tostring(parse))
```

```facts
$ grep -n "cosmic/fs/octal.tl" .cosmic-coverage
182:cosmic/fs/octal.tl 2 2

$ git log --oneline -- _tool/coverage/lines.tl
905341a9 plan skill: two lanes — planners accept, implementers land (#1148)

$ git log --oneline --diff-filter=A -- cosmic/fs/octal.tl
9c7e2a80 fs.octal: one typed octal parser, twenty casts removed (#1154)

$ git log --oneline -- 3p/tl/tl_pin.tl
905341a9 plan skill: two lanes — planners accept, implementers land (#1148)

$ wc -l < _tool/coverage/report.tl
444

$ wc -l < _tool/coverage/report_test.tl
167

$ sed -n '/local zipped = p:match/,/^  end/p' _tool/coverage/report.tl
  local zipped = p:match("^/zip/(.+)%.lua$")
  if zipped then
    -- Two spellings, because the artifact FLATTENS directory modules:
    -- `require("cosmic.fs")` executes `/zip/cosmic/fs.lua`, compiled
    -- from `cosmic/fs/init.tl` -- there is no `cosmic/fs.tl` to find.
    -- Trying only the leaf spelling dropped every directory module in
    -- the tree, so each read as entirely uncovered and its floor went
    -- in at zero: the same "ratchet holds nothing" failure the mapping
    -- above exists to fix, for 14 of this repo's own modules.
    for _, source in ipairs({zipped .. ".tl", zipped .. "/init.tl"}) do
      if not is_excluded(source) and fs.is_file(source) then
        return source, p
      end
    end
    return nil
  end
```

Reference only — narrative, not machine-checked, since it depends on
building binaries and merging synthetic `.cov` fixtures rather than a
single repeatable shell one-liner; recorded here so the reasoning above
is traceable, not as an acceptance-gate fact. Static executable-line
analysis of `cosmic/fs/octal.tl`'s source directly
(`_tool.coverage.lines.executable_lines`) reports executable lines
22, 23, 26, 30 (total 4). The current, unpatched `normalize()` maps a
`/zip/` chunk `@/zip/cosmic/url.lua` to `display=cosmic/url.tl,
parse=/zip/cosmic/url.lua` — the bug being fixed. Isolated single-`.cov`
reproductions against the unpatched code: an `o/`-staged-path-only
`.cov` entry for `octal.tl` reports `covered=2 total=4 missing=26,30
note=nil` (correct); a `/zip`-path-only entry (as `cosmic/script_test.tl`
produces, since it execs a built binary) reports `covered=2 total=2
missing= note=open /zip/cosmic/fs/octal.lua: ENOENT` (the collapse).
After applying the one-line fix and rebuilding, re-running the same
merged 418-`.cov`-file report yields `covered=2 total=4 missing=26,30
note=nil` regardless of merge order.
