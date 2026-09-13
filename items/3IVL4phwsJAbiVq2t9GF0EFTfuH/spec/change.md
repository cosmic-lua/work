Two files, plus one build step.

**1. `3p/tl/tl_patch/narrow.tl`, entry `narrow-metatable-helper` only.**
Inside that entry's `replace` string:

- Change the single line (line 239 today)
  `      local table_kinded = { map = true, record = true, array = true, interface = true }`
  to
  `      local table_kinded = { map = true, array = true }`
  keeping the 6-space indentation the enclosing closure uses.
- Rewrite the carried-patch comment above it (lines 232-238 today) so it
  states what the helper can actually rescue: the is-fact carries the
  UNRESOLVED target type (`ub`), so a named type — a record, an
  interface, or a `type X = {string: any}` alias — arrives with
  `typename == "nominal"` and never reaches this set; only an inline
  `{K: V}` map or `{T}` array literal does. Keep the existing sentences
  about identity against `cache_std_metatable_type` and about `self`
  being passed explicitly; they are still true.
- Update the entry's `note` field to name an INLINE table-kinded
  is-target, e.g.
  `note = "recognize the std metatable<T> nominal against an inline table-kinded is-target"`.

Keep everything else in that entry byte-identical: the `find` anchor (it
anchors on `invalid_from`, which does not move), the `is_table_metatable`
body, and the `table_kinded` table itself — only its contents shrink, so
the two call sites keep compiling unchanged.

Measured 2026-08-27 at main `267c2a4d`, re-measured at pull against
`ae5d1581` — all unchanged:
`wc -l 3p/tl/tl_patch/narrow.tl` → `393` (107 under the 500-line cap);
`grep -c 'record = true' 3p/tl/tl_patch/narrow.tl` → `1`;
`grep -c 'interface = true' 3p/tl/tl_patch/narrow.tl` → `1`;
`grep -c 'table_kinded' 3p/tl/tl_patch/narrow.tl` → `2`;
`grep -c 'is_table_metatable' o/3p/tl/tl.lua` → `3`.

**2. `cosmic/teal_narrowing_test.tl`.** Add three tests after
`test_metatable_is_scalar_is_refused()`, which is the file's last
statement today (line 332). Write each in that file's existing shape:
`fs.write` a subject source into `TEST_TMPDIR`, `teal.check_file` it,
assert on `result.ok`, and call the function on the line after its `end`.

- `test_metatable_is_record_is_refused` — subject source declares
  `local record Handler` with a `name: string` field, then
  `local mt = getmetatable(x)` and `if mt is Handler then return mt.name end`.
  Assert `not result.ok` ("`mt is Handler` (a record nominal) must keep
  failing to check").
- `test_metatable_is_interface_is_refused` — the same with
  `local interface Shape` carrying `kind: string`, and `if mt is Shape`.
  Assert `not result.ok`.
- `test_metatable_is_array_narrows` — subject source is
  `local mt = getmetatable(x)`, `if not (mt is {string}) then return 0 end`,
  `return #mt`. Assert `result.ok`, building the failure text by
  concatenating `result.errors` messages exactly the way
  `test_metatable_is_table_narrows` (line 292) already does.

The first two pin the refusal the trimmed set now honestly describes;
the third pins the array half of the live rescue, which the file does
not cover today, so trimming the set cannot silently drop it.

Measured 2026-08-27 and re-measured at pull: `wc -l
cosmic/teal_narrowing_test.tl` → `332` (168
under the cap); `grep -c '^local function test_' cosmic/teal_narrowing_test.tl`
→ `11`; `grep -c '^local function test_metatable' cosmic/teal_narrowing_test.tl`
→ `2`. All three test bodies above were run verbatim on 2026-08-27 and
passed under `o/bin/cosmic`, under `o/bootstrap/cosmic`, and under a
scratch build with the keys already removed.

**3. Re-apply the patch before gating.** The change is patch DATA, so the
edit does not reach the checker until the pin is re-unpacked and
re-patched: run `bin/cosmic --make fetch` after editing
`3p/tl/tl_patch/narrow.tl`. Measured 2026-08-27 in a scratch clone with
`o/3p/tl/v0.24.8.tar.gz` already present: it prints
`unpack 3p/tl/v0.24.8.tar.gz` then `fetch: PASS (2 pins)` and downloads
nothing. Editing `o/3p/tl/tl.lua` directly is not the change — `fetch`
restores it from the pristine archive.
