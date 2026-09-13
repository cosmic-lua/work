Three files, one build step, one derived-index regen.

**Sequencing — this slice starts after PR #1468 merges.** 3IVL4phw
(#1468) trims `table_kinded` to `{ map = true, array = true }` inside
this very entry, and without that trim the same three lines below admit
records and interfaces, reversing 3ISSFrCO's stated wall. Measured
2026-08-27: with the untrimmed set plus the resolve, `mt is Handler`
flips to `ok=true`; with #1468's trimmed set plus the resolve it stays
`ok=false`. Branch off `origin/main` only once #1468 is merged; every
line number and quoted string below is #1468's post-merge text
(`git show claude/3IVL4phw-table-kinded:<path>`), recorded here so the
implementer can diff rather than guess. `blocked_by` carries the edge.

**1. `3p/tl/tl_patch/narrow.tl`, entry `narrow-metatable-helper` only.**
Inside that entry's `replace` string:

- Insert three lines at the head of `is_table_metatable`'s body, above
  the existing `return table_kinded[target.typename] == true and` line
  (line 246 post-#1468), at the 9-space indentation that `return` uses:

```
         if target.typename == "nominal" then
            target = self:resolve_nominal(target)
         end
```

  This is the shape this same file's `without_nil` already uses
  (`3p/tl/tl_patch/narrow.tl:290-294` on main `73a16882`;
  `grep -c 'resolve_nominal' 3p/tl/tl_patch/narrow.tl` → `3`), so
  `self:resolve_nominal` is established practice inside carried patch
  code and needs no new plumbing. Nothing else in the helper moves.

- Rewrite the two sentences #1468 added about named targets — lines
  237-241 post-#1468, from `-- name. The is-fact carries the UNRESOLVED
  target type (ub), so a` through `-- literal does.` — because this
  change makes them false. The replacement states the new rule: the
  is-fact carries the UNRESOLVED target type (`ub`), so a named type
  arrives with `typename == "nominal"`; resolve it first and judge the
  STRUCTURAL kind, so an inline `{K: V}` / `{T}` and a
  `type X = {K: V}` alias of one are the same case. A record or
  interface nominal resolves to `record` / `interface`, neither of which
  is in this set, so it keeps failing — a metatable carries metamethod
  keys, not a record's declared fields. Keep the surrounding sentences
  (the `-- cosmic carried patch:` opener through `-- name.`, and the
  closing two lines about the call sites sharing the closure and self
  being passed explicitly) byte-identical, and drop the word `inline`
  from the opening sentence, which now over-narrows.

- Change the entry's `note` (line 224 post-#1468) to
  `note = "recognize the std metatable<T> nominal against a map- or array-shaped is-target, inline or named",`

Keep byte-identical: the entry's `find` anchor (it anchors on
`invalid_from`, which does not move — a `find` change is walled below),
`local table_kinded = { map = true, array = true }` exactly as #1468
leaves it, the rest of `is_table_metatable`'s body, and the entries
`narrow-metatable-is` and `narrow-metatable-not`.

**2. `cosmic/teal_narrowing_test.tl`.** One comment amendment and two
new tests.

- Amend the three comment lines 334-336 post-#1468, which read
  `-- ...and a NAMED target never reaches the rescue: the is-fact carries`
  / `-- the unresolved type, so a record nominal arrives as "nominal", not`
  / `-- "record", and the can-never-be refusal stands.` That claim is
  false after this change. Rewrite it to say that the target IS now
  resolved, and a record's resolved typename is not in `table_kinded`,
  so the refusal stands for a different reason. Change nothing else in
  the five existing metatable tests.

- Append these two tests after `test_metatable_is_array_narrows()`
  (line 401 post-#1468, the file's last statement). Both bodies were
  run verbatim on 2026-08-27 (evidence in `Acceptance` item 8):

```teal
-- A named alias of a map narrows exactly as the inline literal does:
-- the rescue resolves a nominal target and judges its structural kind.
local function test_metatable_is_map_alias_narrows()
  local path = fs.join(tmpdir, "narrow_metatable_map_alias.tl")
  assert(fs.write(path, [[
local type Meta = {string: any}
local function m(x: any): boolean
  local mt = getmetatable(x)
  if not (mt is Meta) then
    return false
  end
  return mt.__index ~= nil
end
print(m({}))
]]))
  local result = teal.check_file(path)
  local msgs = {}
  for _, e in ipairs(result.errors) do
    msgs[#msgs + 1] = e.message
  end
  assert(result.ok,
    "a metatable narrowed by `is Meta` (an alias of a map) must check: " ..
    table.concat(msgs, "; "))
end
test_metatable_is_map_alias_narrows()

-- ...and the array half of the same rule.
local function test_metatable_is_array_alias_narrows()
  local path = fs.join(tmpdir, "narrow_metatable_array_alias.tl")
  assert(fs.write(path, [[
local type Names = {string}
local function n(x: any): integer
  local mt = getmetatable(x)
  if not (mt is Names) then
    return 0
  end
  return #mt
end
print(n({}))
]]))
  local result = teal.check_file(path)
  local msgs = {}
  for _, e in ipairs(result.errors) do
    msgs[#msgs + 1] = e.message
  end
  assert(result.ok,
    "a metatable narrowed by `is Names` (an alias of an array) must check: " ..
    table.concat(msgs, "; "))
end
test_metatable_is_array_alias_narrows()
```

**3. `docs/decisions/d32-<slug>.md` — write the record**, then run
`bin/cosmic _docs/derive.tl` to rewrite the derived index table in
`docs/decisions/README.md` (never hand-edit those rows). `32` is the
next free number: `ls docs/decisions/` on main `73a16882` tops out at
`d31-gate-noise-from-every-control-pair.md`, and no local branch claims
a `d32` file (checked with `git ls-tree -r --name-only <branch>
docs/decisions/` over every branch `git branch --format='%(refname:short)'`
lists). Use the four-section form and H1 grammar in
`skills/decide/SKILL.md` (`# D32 — <lowercase claim>`, em dash,
`date: 2026-08`, `status: active`). The record must carry:

- **decision** — the metatable is-rescue resolves a nominal target and
  admits it by its RESOLVED structural kind, restricted to `map` and
  `array`. A target resolving to `record` or `interface` keeps failing;
  so does every scalar, aliased or not. Naming is irrelevant: the source
  side is still identity against `cache_std_metatable_type`.
- **context** — the asymmetry table in `Goal` above, its `ub` cause with
  the `o/3p/tl/tl.lua` site, and the fact that the constraint being
  narrowed lived only in a completed board item's Non-goals (3ISSFrCO)
  until now.
- **rejected**, each with the reason it lost:
  - resolve and admit every table-kinded resolved kind, records and
    interfaces included — one line SHORTER (delete the set), and it is
    what Teal's own `is` does for an `any`-typed value. It loses because
    a `metatable<T>` value carries metamethod keys, so narrowing it to
    `Handler {name: string}` types `mt.name` as `string` for a field
    that does not exist.
  - leave the rescue inline-only and document the limitation. It loses
    because "inline narrows, the byte-identical alias does not" is an
    accident of where the is-fact is built (`ub`, not the resolved
    `rb`), not a property anybody chose, and it teaches users to inline
    a shape they already named.
  - match the target by NAME rather than by resolved kind — already
    rejected by 3ISSFrCO in favour of identity against
    `cache_std_metatable_type`; restated so nobody re-opens it.
- **consequences** — including the accepted cost, measured: the rescue
  is already unsound for the VALUE type, since `mt is {string: integer}`
  checks clean today under the shipped checker (probed 2026-08-27 under
  `o/bootstrap/cosmic` → `ok=true`), typing `mt.__index` as `integer`.
  This decision widens the ways to REACH that hole (by name) without
  creating it; closing it is separate work and this record does not
  claim to. Also state what would make us revisit: an upstream tl that
  builds the is-fact from the resolved type, which deletes the entry
  outright, per D21's maturity clause.

**4. Re-apply the patch before gating.** This is patch DATA: the edit
does not reach the checker until the pin is re-unpacked and re-patched.
Run `bin/cosmic --make fetch` after editing
`3p/tl/tl_patch/narrow.tl`. Editing `o/3p/tl/tl.lua` directly is not the
change — `fetch` restores it from the pristine archive.

Capacity, measured 2026-08-27 (`git show
claude/3IVL4phw-table-kinded:<path> | wc -l`): post-#1468
`3p/tl/tl_patch/narrow.tl` is `397` (103 under the 500-line cap) and
`cosmic/teal_narrowing_test.tl` is `401` (99 under). The drafted test
file with both new tests appended measures `452` lines.
