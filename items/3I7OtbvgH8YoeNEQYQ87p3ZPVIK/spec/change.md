**Scope decided 2026-08-23 (the bounce's open question, settled by
measurement).** Wave 4 is the TWO `_tool/testrun.tl` sites. The four
`cosmic/instrument.tl` sites are a Non-goal here and wait on
3IIm7ZyN — see Non-goals for the measurement that decides it.

Re-measured 2026-08-23 at main `d01ea6ac`. `git grep -n "tonumber" --
'*.tl' | grep "as integer" | grep -v _test.tl` returns 10 sites; the
two this wave takes are:

```
_tool/testrun.tl:232   (tonumber(string.match(got_content, "^(%d+)")) or -1) as integer
_tool/testrun.tl:243   (tonumber(fs.read(base .. ".time") or "") or -1) as integer
```

1. **`cosmic/string.tl`**: add the parser, fallible-value shape.
   Measured now: `wc -l < cosmic/string.tl` is 431 — 69 lines of
   headroom under the 500-line cap, and this addition is ~22 lines (the
   doc comment, the function, one `StringModule` field, one `M` entry),
   so the file lands near 453 and stays under the cap without a split.
   Place the function after `shell_quote`, the last one defined today
   (`grep -n "^local function shell_quote\|^local record StringModule"
   cosmic/string.tl` prints 377 and 387, so `shell_quote` ends at 385);
   the `StringModule` record and the `M` table both list their members
   in definition order, so both new entries go last.

   ```teal
   --- Parse s as an integer. tonumber's grammar (optional sign,
   --- whitespace tolerated; base 2-36, default 10), judged on the
   --- VALUE rather than the spelling: "1e3" is 1000 and "0x1F" is 31,
   --- while "7.5" is a refusal rather than a truncation.
   --- @param s string The text to parse
   --- @param base integer? The base, default 10
   --- @return integer | nil The parsed integer
   --- @return string Error message when s is not an integer in base
   local function to_integer(s: string, base?: integer): integer | nil, string
   ```

   Implementation: `tonumber(s, base)` when `base` is given and
   `tonumber(s)` when it is not — as two branches, never
   `base and tonumber(s, base) or tonumber(s)`, which falls through to
   the base-less call when the based parse legitimately refuses. Then
   `math.tointeger` on the result; either failing returns
   `nil, ("not an integer%s: %q"):format(base and " in base " .. tostring(base) or "", s)`.
   NOT `math.tointeger` bare — its tl declaration swallows nil (the
   census's fine print), which is the whole reason this function exists.

   **The error path must format with `%q`, never with `..`
   concatenation.** `testrun.tl:232` hands this function a value tl
   types as `string` that is nil at runtime: `string.match(got_content,
   "^(%d+)")` returns nil whenever the recorded exit line does not start
   with digits. Measured 2026-08-23 against the pinned runtime:
   `tonumber(nil)` is nil and `("%q"):format(nil)` is `nil`, so the
   base-less call returns the refusal `not an integer: nil` cleanly,
   while `tonumber(nil, 10)` throws `bad argument #1 to 'tonumber'
   (string expected, got nil)`. Library code never throws, so the
   base-less path — the only one either site uses — must stay the safe
   one, and a `..` in the message would throw on exactly this input.
2. **Migrate the two sites**: `str.to_integer(x) or -1` — the `or`
   narrows the nil away, so the cast AND its justification comment
   delete. No other call-shape changes. `_tool/testrun.tl` (337 lines,
   ample headroom) requires six `cosmic.*`/`_tool.*` modules today and
   not `cosmic.string`; its require block is sorted by module basename
   (`child, env, fs, instrument, records, time`), so
   `local str = require("cosmic.string")` goes between `records` and
   `time`. `cosmic.string` is public API (`cosmic.<name>`, no leading
   `_`), so `_tool/` may require it.
3. **Tests** (`cosmic/string_test.tl`, 221 lines today — ample
   headroom): the rule is the VALUE, not the spelling. Every row below
   was run 2026-08-23 against a binary built from this exact
   implementation, so these are the exact expected results:

   | call | result |
   |------|--------|
   | `to_integer("42")` | 42 |
   | `to_integer("-17")` | -17 |
   | `to_integer("  42  ")` | 42 (whitespace tolerated) |
   | `to_integer("1e3")` | 1000 (integral VALUE, exponent spelling) |
   | `to_integer("0x1F")` | 31 (hex prefix, DEFAULT base only) |
   | `to_integer("1F", 16)` | 31 |
   | `to_integer("777", 8)` | 511 |
   | `to_integer("0x1F", 16)` | refusal, `not an integer in base 16: "0x1F"` |
   | `to_integer("7.5")` | refusal, `not an integer: "7.5"` |
   | `to_integer("nan")` | refusal, `not an integer: "nan"` |
   | `to_integer("")` | refusal, `not an integer: ""` |

   Plus one test that a runtime nil earns a refusal rather than a throw,
   which is what keeps `testrun.tl:232` honest: `str.to_integer(nil as
   string)` returns nil and the message `not an integer: nil`
   (`-- cast: tl types string.match as string; it is nil at runtime`).
   Also add one `Example_*` in `cosmic/string_example.tl` — a NEW file:
   this module has no example file today. Follow the house shape
   (`cosmic/ansi_example.tl`): a `--- Examples for the cosmic.string
   module.` header, each `Example_*` requiring its own modules inside
   the function body, and a trailing `-- Output:` comment block naming
   the exact printed lines.
4. **Baseline regen**: the cast ratchet's failure prints its regen
   command, which is `bin/cosmic --make run _build/casts.tl --baseline`
   (`_build/casts.tl:116`). Run it and commit the regenerated
   `_build/casts_baseline.tl`. Measured today, its affected rows read
   `["_tool/testrun.tl"] = 3` (line 37) and `["cosmic/string_test.tl"]
   = 2` (line 125); after this wave they must read 1 and 3 — the −2 this
   wave deletes plus the nil-refusal test's one cast.
   `["cosmic/instrument.tl"] = 7` (line 83) must NOT move.
