Two deliverables, in order. Neither is code.

**1. Write the inventory table into this item's own spec sidecar.**

Read all 38 `test/tool/net/*.lua` and all 31 `tool/lua/test_*.lua`, then
append one new `## Inventory` section to this spec — after
`## Enablement`, so the five ready-bar sections stay as they are —
holding a markdown table of **exactly 38 rows**, one per Lua file, in
`ls` order, with exactly these four columns and this header:

```markdown
| file | surface | covered by | verdict |
|------|---------|-----------|---------|
| test/tool/net/argon2_test.lua | cosmo.argon2 hash/verify | tool/lua/test_argon2.lua | covered |
```

- **file** — the path, verbatim, starting `test/tool/net/`.
- **surface** — the binding surface it exercises, in a few words
  (`cosmo.DecodeJson conformance corpus`, `cosmo.unix.futex`,
  `cosmo.path.join`). Name the binding, not the test.
- **covered by** — the `tool/lua/test_*.lua` path that already covers
  the same ground, or `—` when none does. When two cover parts of it,
  name both, space-separated.
- **verdict** — exactly one of three literal words:
  - `covered` — `tool/lua/` already exercises this ground. Nothing to
    port.
  - `none` — real coverage that exists nowhere else in the fork. Goes
    on a port slice.
  - `retired` — the file asserts a contract this fork deliberately
    replaced (redbean's `:errno()` object, redbean globals the fork
    namespaces under `cosmo.*` with no equivalent, a `cosmo` module
    redbean does not link). The parent settled that these are dropped,
    not repaired; a row is `retired` only when porting it would
    reproduce a `tool/lua/test_*.lua` that already exists, and the
    `covered by` cell must then name that file.

  A file that merely calls a redbean global the fork has under `cosmo.*`
  is NOT `retired` — the body ports under a prelude that binds the
  names. Judge by the contract asserted, not by the spelling of the
  call.

Write it back with `gitboard spec 3ISCk9jy FILE` from the board
worktree. That commit is the first deliverable and must land before the
second.

**2. File one port slice per coherent group of `none` rows**, as
children of `3IOCgCWG`, each blocked on this item:

```text
gitboard new "<title>" --parent 3IOCgCWG --repo cosmic-lua/cosmopolitan --spec-file F
gitboard block <new id> 3ISCk9jy
```

Group by binding surface, not by file count — the 9 json files are one
slice because they are one corpus and one prelude. Each slice's spec
carries the full five sections, and its `Change` names, per file: the
source path, the destination `tool/lua/test_<name>.lua`, the prelude
lines that bind the redbean globals it uses to their `cosmo.*`
equivalents, and the two `tool/lua/BUILD.mk` edits (the `.ok` rule and
the `TOOL_LUA_TESTS` line). Its `Acceptance` carries
`make -j$(nproc) o//tool/lua/test` plus the stamp-count delta for that
slice. Size each for one session: if a group's `Change` needs the word
"and" between two independent surfaces, cut it in two.

If the inventory finds **zero** `none` rows outside the json corpus,
that is a real result — file the one json slice and say so in the
report. Do not manufacture slices to fill a quota.
