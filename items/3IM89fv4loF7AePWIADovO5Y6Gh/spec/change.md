One file: `cosmic/format/init.tl`. Measured 2026-08-24 at `d1dff351`
(`wc -l cosmic/format/init.tl` = **383**, so **117 lines of headroom**
under the 500-line cap; the prototype landed at 398, and Acceptance
bounds it).

The emit pass appends to one `out: {string}` accumulator at 12 sites
(`grep -c "out\[#out + 1\]" cosmic/format/init.tl` = **12**, at lines
182, 184, 257, 268, 283, 295, 297, 299, 301, 305, 308, 315), one
fragment per token, per space, per indent run and per newline — so a
~2160-token module pushes several thousand entries into a single growing
table before the final `table.concat`. **Buffer a line and concat it
once**, so `out` grows with lines rather than with fragments.

In `format`'s emit loop (`for _, line in ipairs(lines) do`, line 253):

- Declare the reused buffer immediately before that loop, beside
  `continues_type`/`type_depth`:

      local buf: {string} = {}
      local bn = 0

  One table for the whole function, reused across lines — allocating a
  fresh `{}` per line would trade one kind of table churn for another.
- Reset the count, not the table, as the first statement inside the loop
  body, after the existing blank-gap `out[#out + 1] = "\n"` at line 257:
  `bn = 0`. Stale entries past `bn` are never read because the concat is
  bounded (below).
- Rewrite the **nine** in-line append sites — lines 268, 283, 295, 297,
  299, 301, 305, 308 and 315 — from `out[#out + 1] = X` to the two-line
  form `bn = bn + 1` / `buf[bn] = X`, preserving indentation and the
  right-hand side exactly.
- Immediately after the line-terminating `buf[bn] = "\n"` (line 315
  today) and before `indent = math.max(0, indent + post_change)`, append
  the finished line:

      out[#out + 1] = table.concat(buf, "", 1, bn)

  The explicit `1, bn` bounds are what make reuse-without-clearing
  correct; `table.concat(buf)` would read stale entries from a longer
  previous line.
- **The three remaining `out` sites do not move.** Lines 182 and 184 are
  the shebang, emitted before the loop; line 257 is the blank-line gap
  emitted *between* lines. Neither is part of a line's text.

Nothing else changes: no rule, no `Item` field, no pass order, no
signature.

**Verified, not proposed.** This exact shape was built and gated during
refinement on 2026-08-24 at `d1dff351`: `bin/cosmic --make ci` ended
`ci: PASS`, `wc -l` was 398, the diff was +24/−9, and the two grep counts
below came out at 4 and 9.

**What it buys, measured.** Three runs of the scenario against the
prototype build, against a baseline run of the same command on the
unmodified tree:

| | `alloc_kb` | wall |
|---|---|---|
| baseline | 1478.08 | 7.52 ms ± 4.9% |
| prototype | 1432.96, 1432.98, 1432.98 | 7.05 ms ± 5.9%, 8.63 ms ± 31.0%, 8.11 ms ± 15.3% |

— i.e. **−45.12 KB, −3.05%** of the scenario's allocation, deterministic
across runs, and **no wall-clock result**: this host's spread on this
scenario reached 31%, which swamps any change of this size. Do not sell
this as a speed-up; `alloc_kb` is the claim, and Acceptance gates only
that. Commands:

    o/bin/cosmic --make run _perf/run.tl --only format --out o/perf/format-X.json
    o/bin/cosmic -e 'local j,f=require("cosmic.json"),require("cosmic.fs") for _,s in ipairs(j.decode(f.read("o/perf/format-X.json")).results) do if s.name=="format_module_source" then print(s.alloc_kb) end end'
