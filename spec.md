## Goal

`tool/lua/test_definitions_coverage.lua`'s annotation-quality ratchet
checks that a binding's `definitions.lua` annotation is present and
that its declared return arity matches what the C source actually
pushes — it does not check that a declared slot's TYPE matches what
that slot actually holds at runtime. A binding whose annotation gets
the arity right but assigns the wrong type to a shared/doubling slot
(the exact class of bug the `unix.nanosleep`/`unix.tiocgwinsz`-family
fixes exist to correct) passes the ratchet both before and after such
a fix, so the ratchet cannot itself catch a regression that reintroduces
the same mislabeling.

## Evidence

Found live during the build of board item `3IiFbfUJTDG5D8ovqA8IzNoHNOt`
(`unix.tiocgwinsz`'s annotation fix, PR #335, cosmic-lua/cosmopolitan).
The builder's own mutation test: reverted `unix.tiocgwinsz`'s
`definitions.lua` annotation to the pre-fix, WRONG shape (a fixed
4-slot `rows, cols:integer, error:string?, errno:unix.Errno?`, when the
C implementation only ever returns 2 values on success or 3 on
failure, with the error string landing in the declared `cols` slot),
then re-ran `make -j4 o//tool/lua/test`. The full suite — including
`test_definitions_coverage.lua`'s presence/arity/conformance checks —
passed. The wrong annotation is textually well-formed and declares a
plausible (if false) arity, so nothing in the existing ratchet
distinguishes it from the corrected one.

## Change

Add one new static check to `tool/lua/test_definitions_coverage.lua`,
in the same shrink-only-ratchet style as its existing ones
(`ARITY_ALLOW`, `QALLOW_*`), that ties a binding's declared per-slot
TYPE — not just its slot COUNT — to the one fixed failure shape the
file's arity check already resolves through: `LuaUnixSysretErrno`'s
`nil, string, integer` triple.

**The gap, confirmed in the tree today (static reading only, no build
run — this task never touches the product tree):**

- `test_definitions_coverage.lua`'s "return-arity conformance" section
  (`declared_return_count`, `max_returns`, `arity_vio` — starts at
  `-- ===== return-arity conformance =====` on line 1116, confirmed
  with `grep -n "return-arity conformance" tool/lua/test_definitions_coverage.lua`)
  compares only the NUMBER of `---@return` lines against the C's max
  pushed value count (fails only when `declared > actual`). Reading
  the full 1517-line file top to bottom, nothing in it, in this
  section or any other, ever reads a slot's declared TYPE text and
  compares it to what the C can actually push into that position.
- `test_definitions_conformance.lua` DOES compare declared per-slot
  types against real runtime values (`value_matches` inside
  `probe()`), but only for the curated, grow-only-by-design `PROBES`
  set of calls made in that file. `unix.tiocgwinsz` and
  `unix.nanosleep` — the two bindings this item's title names as the
  motivating family — are not in it:
  ```
  $ grep -n tiocgwinsz tool/lua/test_definitions_conformance.lua
  $ grep -n nanosleep tool/lua/test_definitions_conformance.lua
  ```
  both produce no output. Neither can realistically be added: forcing
  `tiocgwinsz`'s `ioctl(TIOCGWINSZ, ...)` to fail, or forcing
  `nanosleep`'s syscall to return `EINTR`, needs a real controlling
  tty / real signal delivery that a hermetic unit test can't arrange —
  the same reason `SLOT_UNPROBED` in that file already carries several
  other ioctl/errno-dependent slots as permanently unprobeable.
- So today, a binding of this shape has NO check on its per-slot type:
  neither the coverage file's arity check (types never read) nor the
  conformance file's probe (binding not in, and not practically
  addable to, `PROBES`).
- This shape is not rare or hypothetical. It is exactly: a binding
  whose only failure return is `LuaUnixSysretErrno(...)` (the fork's
  fixed `nil, string, integer` triple, `third_party/lua/cosmo/lunix.c:219-238`)
  AND whose success path pushes 2 or more values — so the success
  path's 2nd value and the failure triple's error string both land in
  return slot #2. A scoping scan of `third_party/lua/cosmo/lunix.c`
  today finds several such bindings beyond `tiocgwinsz`:
  ```
  $ python3 - <<'EOF'
  import re
  src = open('third_party/lua/cosmo/lunix.c').read()
  starts = [(m.start(), m.group(1))
            for m in re.finditer(r'\nstatic int (Lua\w+)\(lua_State\s*\*L', src)]
  starts.append((len(src), None))
  for i in range(len(starts) - 1):
      pos, name = starts[i]
      body = src[pos:starts[i + 1][0]]
      if 'LuaUnixSysretErrno' in body:
          lits = sorted(set(int(x) for x in re.findall(r'return\s+(\d+)\s*;', body)) - {0})
          if any(n >= 2 for n in lits):
              print(name, lits)
  EOF
  LuaUnixFcntl [1, 5]
  LuaUnixOpenpty [3]
  LuaUnixMkstemp [2]
  LuaUnixGetsockopt [1, 2]
  LuaUnixSocketpair [2]
  LuaUnixTiocgwinsz [2]
  LuaUnixDirRead [1, 4]
  ```
  (This scan does not strip comments/string literals the way the
  file's own `strip_c_literals` does, so a literal in a comment could
  in principle contaminate a count — treat this list as "worth
  checking," not as a final verdict; the check being added does its
  own more careful classification, see below.)
- `unix.tiocgwinsz`'s CURRENT, already-fixed annotation already types
  slot 2 as `integer|string` (`tool/net/definitions.lua:7470-7478`), so
  it already satisfies the rule below with no allowlist entry needed.
- `unix.nanosleep` sidesteps the whole class at the C level instead:
  its current implementation (`third_party/lua/cosmo/lunix.c:1707-1739`)
  bundles both success values into one `{seconds, nanos}` table, so
  its own success arity is 1, not 2 — the new check will not flag it,
  and it needs no annotation change. (It will not appear in the scan
  above for the same reason.)

**The check to add:**

1. Scope: any registered `unix.*` binding — plain function or class
   method (`unix.Dir:read` etc.) — whose C implementation lives in
   `third_party/lua/cosmo/lunix.c` and whose body contains a call to
   `LuaUnixSysretErrno` on some return path (directly
   `return LuaUnixSysretErrno(...)`, or via an intermediate variable as
   `nanosleep` does: `rc = LuaUnixSysretErrno(...); ...; return rc[+N]`).
   Generalizing this rule to the equivalent fixed-triple failure
   helpers other modules may have (`lre.c`, `lzip.c`, `lsqlite3.c`,
   `largon2.c`, `lpath.c`) is explicitly out of scope for this item —
   see Non-goals.
2. For each such binding compute its **success-only arity**: the
   largest literal `return <integer>;` directly in its own body.
   Do NOT reuse `max_returns` for this number — that function
   correctly resolves a call like `return LuaUnixSysretErrno(...)`
   into arity 3 (which is exactly right for the existing total-slot
   bound, `arity_vio`, that this new check leaves untouched), but that
   resolved 3 must be excluded here, or every candidate would
   trivially read as arity ≥ 2 and the check would be vacuous. In this
   codebase's convention a success path always returns a literal count
   directly (visible in every candidate above); only the failure path
   delegates to a helper call.
3. When success-only arity is ≥ 2, read the declared type text of that
   binding's 2nd `---@return` line in `tool/net/definitions.lua`
   (locate the annotation block the same way `declared_return_count`
   already does: walk back over the contiguous `---` block above
   `function unix.<name>(` or `function unix.<Class>:<name>(`) and fail
   unless that type text contains the whole token `string` — matched
   on a word boundary the way `qbare` already matches `any`/`table`
   (`%f[%w]string%f[%W]`), so it accepts `integer|string`,
   `string|integer`, or any wider union, but doesn't false-positive on
   an unrelated identifier that merely contains the substring.
   - Slot 1 needs no new check: the failure triple's `nil` is already
     covered by every `T|nil` narrowing rule the rest of the file
     enforces.
   - Slot 3 needs no new check: the failure triple's `integer` errno
     already coincides with every 3rd success value among the
     candidates above (all integers) — restricting this rule to slot 2
     is deliberate scoping, not an omission to fix later.
4. Ratchet it exactly like every other check in this file: a
   shrink-only allowlist (naming is the builder's call, e.g.
   `SHARED_SLOT_ALLOW`, keyed `"unix.<name>"` / `"unix.<Class>:<name>"`)
   seeded with whatever the real scan finds still violating the rule
   once it runs for real; a stale entry (now compliant) must fail too,
   matching `ratchet()`'s existing behavior. Seeding the allowlist for
   a non-trivial finding is an acceptable, expected outcome of adding
   this check — the same way `ARITY_ALLOW`/`QALLOW_*` were seeded when
   each was introduced — fixing every finding's annotation is not
   required by this item.
5. Print a one-line summary in the same style as the file's existing
   three (`definitions coverage: ...`, `annotation quality: ...`,
   `return arity: ...`).
6. Add a small self-check fixture in the same spot the file already
   pins its own parsers against regressions (`TYPE_FIXTURES`,
   `NOSUCCESS_FIXTURES`, `LINE_FIXTURES`): a couple of in-memory
   C-body-shaped strings plus declared-type strings, run directly
   through the new success-arity/slot-2 classifier, asserting it flags
   a `tiocgwinsz`-shaped WRONG case (success-only arity 2, slot 2 typed
   bare `integer`) and passes the CURRENT fixed shape (slot 2 typed
   `integer|string`). Without this, the check's own correctness rides
   entirely on today's real bindings happening to already comply,
   which is exactly the kind of silent-pass risk the file's own
   comments warn against for every other fixture-backed check.

Touches only `tool/lua/test_definitions_coverage.lua` (the new check +
its fixture) and, only as needed, `tool/net/definitions.lua` (seeding
the new allowlist for whatever the real scan turns up, or fixing a
trivial one). No `.c` file changes and no runtime-behavior changes —
this is a harness-only PR. `make -j$(nproc) o//tool/lua/test` must be
green when it's done, exactly as this repo's AGENTS.md already
requires before any PR.

## Non-goals

- Generalizing the rule to the equivalent fixed-triple failure helpers
  in other modules (`lre.c`, `lzip.c`, `lsqlite3.c`, `largon2.c`,
  `lpath.c`, if any exist) is a separate, later item — this one is
  `unix` / `LuaUnixSysretErrno` only.
- Adding `unix.tiocgwinsz`, `unix.nanosleep`, or any other binding to
  `test_definitions_conformance.lua`'s `PROBES` is not this item's job,
  and is likely not hermetically possible for these two specifically
  (see Change) — that file's growable coverage is a separate ratchet.
- Auditing or fixing every binding the scoping scan above turned up is
  not required: seeding the new allowlist for a non-trivial finding is
  an acceptable outcome of this PR, exactly like every other ratchet
  in this file when it was introduced.
- Not a defect in PR #335 or any single binding fix — those diffs are
  correct; this closes a gap in the harness meant to guard them.
