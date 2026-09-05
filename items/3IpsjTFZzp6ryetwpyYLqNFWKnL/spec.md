## Evidence

`MVs4_UosO` re-measured 2026-09-03: the evidence repro reproduces
literally (`local n: number = 3; local j: integer = n` → `Type check
passed`), but the root cause is `narrowed_declaration`
(`tl.lua` local_declaration handler, ~line 13183 in the pinned tl
0.24.8 with cosmic's own patches applied): a local's flow-tracked type
is re-narrowed to its *initializer's* inferred type whenever narrower
than the declared one, so `n`'s tracked type becomes `integer` (from
literal `3`), not the declared `number`, before any `integer`-slot
comparison runs.

This refinement re-measured against `bin/cosmic --make fetch` then
`--make build` (pinned tl 0.24.8, `o/3p/tl/tl.lua`), and extends the
census:

- The gap is not limited to `local j: integer = n`. The identical
  laundering fires at ANY read of such a local, including a function
  call argument — a case the previous evidence pass had filed under
  "already refused" by conflating it with the genuinely-typed-parameter
  case:

      local function take(x: integer) end
      local n: number = 3
      take(n)

  measured (raw pinned tl.lua via `o/3p/cosmos/lua`, `tl.check_string`):
  `OK: type check passed`. The control — `n` as a genuine `number`
  PARAMETER (no literal to narrow from) passed the same way — still
  refuses, unpatched: `argument 1: got number, expected integer`
  (`local function caller(p: number) take(p) end`). So the "already
  refused, no patch needed" census claim holds only for genuinely
  `number`-typed values; it does not hold for a `number`-declared
  local whose initializer happens to be an integer literal, at ANY use
  site, not only its own declaration.

- The general narrowing mechanism itself is otherwise sound and
  closure-safe, confirmed by measurement — a mutation through a
  closure correctly widens the narrowed type back to the declared one
  before the next use:

      local n: number = 3
      local function mutate() n = 3.5 end
      mutate()
      local j: integer = n

  (`o/bin/cosmic --check types`, unpatched): `error: in local
  declaration: j: got number, expected integer`. This means the
  problem is not that `narrowed_declaration` is unsafe in general (it
  is the same mechanism that lets `local x: Base = Derived()` track as
  `Derived`, and D21's cost/benefit does not apply to disabling it
  wholesale) — the problem is specifically that a `number`-declared
  slot's DECLARED width should not be erasable by an integer-literal
  initializer under a strict-integer gate, even though doing so is
  locally sound at that one program point.

- A candidate fix — skip re-narrowing (skip the `narrowed_declaration`
  `add_var` call) only when the ORIGINAL declared type's typename is
  exactly `number` and the about-to-be-narrowed type's typename is
  exactly `integer`, gated behind `COSMIC_INTEGER_STRICT=1` (same
  variable name and read-per-site style as `3p/tl/tl_patch/cast.tl`'s
  `COSMIC_CAST_LEGALITY`) — was built and measured end to end:
  1. patched `o/3p/tl/tl.lua` in place (a scratch edit to the fetched,
     already-patched output — not the tracked patch file, restored
     after measurement) and rebuilt: `o/bin/cosmic --make build` →
     `build: PASS (622 files, 1 binary)`.
  2. `o/bin/cosmic --check types` on `local n: number = 3\nlocal j:
     integer = n\nprint(j)`:
     - gate unset: `Type check passed`
     - `COSMIC_INTEGER_STRICT=1`: `error: in local declaration: j: got
       number, expected integer` / `hint: annotate the variable :
       number, or convert with math.tointeger; integer is required for
       string indices/lengths` — the EXISTING stock `is_a` refusal and
       the EXISTING `_teal_hints.tl` hint fire unmodified; no new `is_a`
       comparison rule or new error message is needed at all, because
       once the operand is no longer laundered to `integer`, stock tl
       already refuses `number` where `integer` is declared (per the
       census above).
  3. Full-tree regression with the same patched checker, gate OFF (the
     default the tree ships with): `o/bin/cosmic --make ci` → `288
     checks: 287 passed, 1 skipped` / `3338 tests: 3338 passed` /
     `coverage ratchet ok` / `coverage: PASS (288 files)` / `ci: PASS
     (5 stages)` — byte-identical result to an unpatched build's gate,
     confirming the gate is fully inert by default.

This resolves the open question: the narrowing IS the real gap, it is
reachable at more sites than the original census found, and a minimal,
exactly-anchored patch to `narrowed_declaration` (not to `is_a`) closes
it without a new comparison rule. `MVs4_UosO`'s planned `is_a` entry
for this shape is superseded — stock `is_a` already does the refusing
once the operand reaches it honestly.

## Change

One patch entry plus its canary test. Nothing else — `MVs4_UosO`
retains the `math.type` narrowing entry and the tree-wide census/doc,
neither of which this change touches or requires (see Non-goals).

**`3p/tl/tl_patch/integer.tl`** (new file, entry name
`integer-strict-declaration`, `file = "tl.lua"`) — model the file's
header comment on `3p/tl/tl_patch/cast.tl`'s (mechanism paragraph,
carried-not-forked paragraph, probing paragraph verbatim; swap only the
what-this-entry-does paragraph). The entry:

```lua
    find = [=====[                     t = self:infer_at(w, infertype)
                     self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                  end
               end]=====],
    replace = [=====[                     -- cosmic carried patch (prototype: gated,
                     -- not enabled — see 3p/tl/tl_patch/cast.tl for the
                     -- sibling pattern): a `number`-declared local's
                     -- DECLARED width must not be erasable just because
                     -- its current initializer happens to be an integer
                     -- literal — that is what let `local n: number = 3;
                     -- local j: integer = n` and `take(n)` (an
                     -- `integer`-parameter call) pass unchecked. Skipping
                     -- narrowed_declaration's add_var call here leaves n
                     -- tracked at its DECLARED type, so every downstream
                     -- use hits stock is_a(number, integer) honestly —
                     -- no new comparison rule needed.
                     local declared_t = t
                     t = self:infer_at(w, infertype)
                     if not (os.getenv("COSMIC_INTEGER_STRICT") == "1" and
                        declared_t.typename == "number" and t.typename == "integer") then
                        self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                     end
                  end
               end]=====],
```

(Anchor measured unique-once in the pinned, already-patched
`o/3p/tl/tl.lua`: `grep -c '"narrowed_declaration"'` → 2 total in the
file, one in `widen_in_scope`'s specialization check, one in this
`add_var` call — the `find` string above's four-line shape is the
narrower, uniquely-matching anchor actually used, confirmed by
`grep -c` returning 1 for the exact block during this refinement.)

**`cosmic/teal_integer_strict_test.tl`** (new file — `cosmic/teal_test.tl`
is at exactly 500 lines already, `wc -l cosmic/teal_test.tl` → `500`,
so a new patch's canary cannot go there; follow the established split
convention `teal_narrowing_test.tl`/`teal_closure_test.tl` already use
for other `tl_patch` groups' canaries, same header-comment shape: "The
integer-strict half of the carried tl patch... Split from
teal_test.tl by convention (a new gate gets its own canary), not by
the line cap."). Two cases, using `cosmic.env.set`/`.get`/`.unset`
exactly as `_make/policy_test.tl` already does around
`COSMIC_COVERAGE_ENV` (save prior value, restore after):

- gate OFF (no `env.set` call at all): `teal.check_file` on `local n:
  number = 3\nlocal j: integer = n\nprint(j)` asserts `result.ok`.
- gate ON (`env.set("COSMIC_INTEGER_STRICT", "1")`, restore via prior
  value or `env.unset` in a way that runs even if the assertions fail):
  `teal.check_file` on the same source asserts `not result.ok` and
  that some error's `.message` contains `"got number, expected
  integer"`.

No other file changes. `o/bin/cosmic --make ci` must end `ci: PASS`
with the gate off (the default, unaffected per the measurement above).

## Non-goals

- Not the `math.type(x) == "integer"` narrowing entry, and not the
  tree-wide census or `docs/design/integer-strictness.md` — both stay
  `MVs4_UosO`'s scope (or a re-filed successor); bundling them here
  would be exactly the "and" the sizing rule says to cut apart, and
  neither depends on this patch or is depended on by it.
- Not touching `narrowed_declaration`'s general behavior: the gate
  checks `declared_t.typename == "number"` and the narrowed
  `t.typename == "integer"` by exact typename, so record/interface
  narrowing (`local x: Base = Derived()`) and every other narrowed
  type pair is untouched — verified by construction (the typename
  check), not just by intent.
- Not extending the gate to a type ALIAS of `number` (`type Meters =
  number`) or to a `number`-containing union declaration — only a
  bare `number`-typed declaration is covered, matching exactly what
  was measured in this pass. Widening to aliases is unmeasured and
  left for a follow-up if it turns out to matter.
- Not un-gating `COSMIC_INTEGER_STRICT` by default, and no
  `bin/cosmic.pin` bump — a gated, off-by-default patch changes no
  in-tree result (confirmed: `--make ci` gate-off is unaffected), so
  neither applies.
