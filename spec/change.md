Delete both tolerant map views, call the typed APIs, and rewrite the
committed cast floor. Four files, one of them a generated baseline.

**1. `_perf/run.tl`** — replace lines 148-166 (the seven-line comment, the
two `-- cast:` justifications, the `version_fn` lookup and its `type()`
guard) with the typed read:

```teal
  -- Absent rather than guessed, like `bin_sha` above: outside a packed
  -- binary there are no stamps, and a results file that cannot name the
  -- versions it measured carries neither field.
  local v = cosmic.version_info()
  if v then
    meta.cosmic_version = v.cosmic
    meta.cosmos_version = v.cosmos
  end
```

`cosmic.version_info` is declared `function(): VersionInfo | nil` with
`cosmic: string` and `cosmos: string` (`cosmic/init.tl:11-14, 55, 86`), so
the guard on the local is the whole narrowing and no cast survives.
`local cosmic = require("cosmic")` at `_perf/run.tl:17` stays — this is now
its only use. 405 → 394 lines.

**2. `_perf/bench/literal_bench.tl`** — delete lines 67-89 whole: the
ten-line comment, the three `-- cast:` justifications, `lit`, `format_any`,
`format_one`, and `supports_compact`. Then make the compact scenario
unconditional — replace lines 183-194 (keeping the `-- Third, not
appended:` comment at 180-182 exactly as it is) with:

```teal
  table.insert(list, 3, {
      name = "literal_format_floor_compact",
      fn = function(_: any): any
        return (literal.format(FLOOR, {layout = "compact"}))
      end,
      check = function(_: any, res: any): boolean, string
        return verify("literal_format_floor_compact", res, FLOOR_ROWS, FLOOR_KEY,
          "covered", FLOOR_COVERED)
      end,
    })
```

206 → 180 lines. `literal` is already required at line 18 and already used
by the other four scenarios.

**3. `_perf/skew_test.tl`** — three mentions of `literal_bench` become
dangling once the pattern is gone: it is the file skew_test tells a future
session to copy. State the pattern in place instead. Exactly three edits,
nothing else in the file:

- lines 9-14 become

```teal
--- therefore crashes the release lane days after the use merges, with
--- no PR left to attribute it to. The baseline side runs the tree's
--- `_perf` entirely, not only its path-given entry, so every module in
--- it is exposed, not just the harness.
```

- lines 32-36 become

```teal
--- When this fails, read it two ways. A `cosmic` API newer than the
--- pin: wait for the pin to catch up, or reach the API through a
--- tolerant map view plus a capability probe -- look the name up on
--- `<module> as {string: any}`, confirm at run time that this binary
--- really has it, and skip the work when it does not. Anything else:
--- a genuine type error in a `_perf` file, to fix as one.
```

- lines 101-103, inside the assert message, become

```teal
    "a cosmic API newer than the pin, wait for the pin, or look the " ..
    "name up on a {string: any} view of the module and probe at run " ..
    "time that this binary has it; otherwise it is an ordinary type " ..
    "error:\n" .. r.stderr)
```

The file stays 105 lines. Nothing outside skew_test reads that message:
`git grep -n 'tolerant map view' -- .` returns only `_perf/skew_test.tl:33`
and `:101`.

**4. Rewrite the cast floor.** Both files drop to zero casts, so the
ratchet fails with "file(s) under their cast baseline" until the floor is
rewritten. Run exactly the command its failure prints —
`bin/cosmic --make run _build/casts.tl --baseline` — and commit
`_build/casts_baseline.tl`. Today it carries
`["_perf/bench/literal_bench.tl"] = 3` and `["_perf/run.tl"] = 2` at lines
12 and 15; both rows disappear. No other row may move.

**5. If, and only if, the coverage ratchet complains**, run exactly
`bin/cosmic --make coverage --baseline` and commit `.cosmic-coverage`. The
two rows at risk are `["_perf/bench/literal_bench.tl"] = {82, 87}` and
`["_perf/run.tl"] = {97, 191}` (`.cosmic-coverage:102, 120`); both lose
executable lines, and run.tl's percentage sits within a point of its own
tolerance, so a regen may or may not be needed. Never lower a row by hand,
and never lower one the gate did not name.
