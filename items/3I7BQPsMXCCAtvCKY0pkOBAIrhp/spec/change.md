Measured 2026-08-19 at `f420391` — the formatter is the private module
`cosmic/_literal_format.tl` (216 lines), so no public contract moves:

1. In `render_table` (line 119), the nested-table branch (~137–142)
   currently always emits `lead .. "{"`, recurses, then `pad .. "},"`.
   New rule: when EVERY value of the nested table is a scalar
   (vacuously true for the empty table), render the whole entry on one
   line — `lead .. "{ " .. <sorted "[key] = value," entries joined by
   one space, last comma kept> .. " },"` (empty: `lead .. "{},"`). A
   nested table containing a table keeps today's multi-line layout.
   Key sorting, quoting, `MAX_DEPTH`, and every refusal are untouched.
2. Update the module doc's layout paragraph (~156–165) — it states the
   fixed layout, and the inline case joins that statement.
3. **Tests** (`cosmic/literal_test.tl`, 381 lines, 119 of headroom):
   `parse(format(v))` round-trips a flat nested table; the rendered text
   for `{["a.tl"] = {["covered"] = 1, ["total"] = 2}}` is exactly three
   lines; a doubly-nested table stays multi-line; the empty nested
   inline form parses back. The stated `format` contract "output is a
   fmt fixpoint" (literal.tl:389) must hold for the new layout — assert
   it the way the existing fixpoint coverage does, and if
   `cosmic --check fmt` rewraps the one-line form, that is a refusal of
   this design to surface at implementation, not to paper over.

Blast radius, measured: no committed file changes bytes — the two
`_build` floors hold only scalars (`grep -c '= {' _build/casts_baseline.tl`
is 0), and the only other writer is the coverage collector's `.cov`
bodies under `o/` (uncommitted; content-keyed caches re-key once).
