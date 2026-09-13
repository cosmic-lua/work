Three call sites independently ask the kernel for its Landlock ABI
version via the argument-less probe form of
`unix.landlock_create_ruleset()` — `cosmic/sandbox/landlock.tl`'s own
`abi()` (the canonical one, already cached), plus two duplicates in
`cosmic/sandbox/unveil.tl` and `cosmic/quicksand/init.tl` that each
re-run the raw syscall and keep their own separate cache/logic. Make
`cosmic.sandbox.landlock.available()` (already exported, already
cached via `abi_cached`/`abi_probed`) the one place that knowledge
lives; the other two delegate to it and drop their own probing.

1. **`cosmic/sandbox/unveil.tl`**: add
   `local landlock = require("cosmic.sandbox.landlock")` alongside the
   existing `local unix = require("cosmo.unix")` (line 26). Replace the
   `available()` function (currently lines 62–85: the module-level
   `local avail: boolean = nil` cache plus the function body) with a
   version that has no local cache of its own and delegates the LINUX
   branch to `landlock.available()`:

   ```teal
   --- True when unveil is actually enforceable on this host: OpenBSD, or
   --- Linux with Landlock ABI >= 1. Derived, never probed with unveil
   --- itself — `unix.unveil(nil, nil)` is the commit call, so probing it
   --- would lock this very process into a deny-all sandbox. The libc backs
   --- unveil with Landlock on Linux, so it enforces exactly when Landlock
   --- does; everywhere else the raw call deliberately fails open, which is
   --- precisely what this wrapper refuses to pass through. The Linux
   --- answer delegates to cosmic.sandbox.landlock.available(), the one
   --- cached probe every Landlock-availability check shares.
   ---
   --- @return boolean True when unveil can be enforced
   local function available(): boolean
     local host = cosmo.GetHostOs()
     if host == "OPENBSD" then
       return true
     elseif host == "LINUX" then
       return landlock.available()
     end
     return false
   end
   ```

   Delete the now-unused `local avail: boolean = nil` line entirely —
   `landlock.available()` is already memoized, so a second cache here
   is exactly the duplication R5 asks to remove, not a safety margin.
   `unix` stays imported (`allow`/`commit` still call `unix.unveil`
   directly).

2. **`cosmic/quicksand/init.tl`**: add
   `local landlock = require("cosmic.sandbox.landlock")` alongside the
   existing requires (after line 19's `local unix = require("cosmo.unix")`
   is fine). Replace `probe_landlock()` (lines 79–84) with:

   ```teal
   --- Landlock availability, delegated to cosmic.sandbox.landlock's
   --- cached probe — the one place Landlock ABI knowledge lives,
   --- shared with cosmic.sandbox.unveil.
   local function probe_landlock(): boolean
     return landlock.available()
   end
   ```

   Keep the function (rather than inlining `landlock.available()` at
   its one call site, line 146) so it reads consistently with its
   neighbors `probe()` and `probe_ns()`, each a named probe in the
   same list. `capabilities()`'s own top-level `cached` table is
   untouched — this only changes what `probe_landlock()` does when
   `capabilities()` calls it the first time.

3. **`cosmic/sandbox/landlock_test.tl`**: add a regression test that
   keeps the dedup real — a guard against a *new* direct call
   reappearing elsewhere, which is exactly how the tree ended up with
   three copies. Using `cosmic.fs.find(root, {glob = "*.tl", recursive
   = true})` over the `cosmic/` tree (relative to the repo root, which
   the test can locate the same way other sandbox tests locate
   `TEST_BIN`/fixtures — via a path relative to this test file, or
   `os.getenv("TEST_TMPDIR")`'s sibling project checkout, whichever
   this repo's other tree-scanning tests already use), read each file
   with `cosmic.fs.read`, and count lines containing the literal
   substring `unix.landlock_create_ruleset()` (bare, no-arg form —
   `:find(needle, 1, true)`, a substring search, not a pattern).
   Assert the count is exactly 1, and that the one file it appears in
   is `cosmic/sandbox/landlock.tl`. This does not touch
   `cosmic/sandbox/landlock.tl` itself — its own two calls, one bare
   (`unix.landlock_create_ruleset()`, the probe) and one with
   arguments (`unix.landlock_create_ruleset(handled, 0)`, the real
   ruleset creation), are unaffected; only the bare form is counted.

```facts
$ wc -l cosmic/sandbox/unveil.tl cosmic/quicksand/init.tl cosmic/sandbox/landlock.tl cosmic/sandbox/landlock_test.tl cosmic/quicksand/init_test.tl
  145 cosmic/sandbox/unveil.tl
  184 cosmic/quicksand/init.tl
  295 cosmic/sandbox/landlock.tl
  327 cosmic/sandbox/landlock_test.tl
  186 cosmic/quicksand/init_test.tl
 1137 total
$ grep -rn "landlock_create_ruleset()" cosmic/ --include=*.tl | grep -v _test
cosmic/quicksand/init.tl:82:  local abi = unix.landlock_create_ruleset()
cosmic/sandbox/landlock.tl:158:    local v, err = unix.landlock_create_ruleset()
cosmic/sandbox/unveil.tl:79:    local abi = unix.landlock_create_ruleset()
$ grep -rln "landlock_create_ruleset()" cosmic/ --include=*_test.tl
$ grep -n "landlock_create_ruleset" cosmic/sandbox/landlock.tl
158:    local v, err = unix.landlock_create_ruleset()
205:  local rs, cerr = unix.landlock_create_ruleset(handled, 0)
$ grep -rn "cosmic.sandbox" cosmic/quicksand/*.tl
cosmic/quicksand/caps.tl:48:  --- the cosmic.sandbox mechanism shards (pledge, unveil, landlock).
cosmic/quicksand/init.tl:7:--- `cosmic.sandbox` facade (landlock + pledge) for its fs and syscall
cosmic/quicksand/types.tl:8:local sandbox = require("cosmic.sandbox")
cosmic/quicksand/types.tl:51:--- The filesystem policy is cosmic.sandbox's Fs schema (ro/rw/exec
cosmic/quicksand/types.tl:65:--- The system-call policy is cosmic.sandbox's Sys schema (pledge
$ grep -n "^local .* = require" cosmic/sandbox/landlock.tl
24:local unix = require("cosmo.unix")
25:local seal_coverage = require("cosmic._seal_coverage").seal_coverage
```
`cosmic/quicksand/types.tl` already requires `cosmic.sandbox` (the
facade) directly, so a sibling module (`cosmic/quicksand/init.tl`)
requiring `cosmic.sandbox.landlock` (an internal shard, per
`cosmic/doc/visibility.tl`'s one-segment-only public rule — anything
under `cosmic/` may require an internal shard also under `cosmic/`) is
an established, precedented direction. `cosmic/sandbox/landlock.tl`'s
own requires (`cosmo.unix`, `cosmic._seal_coverage`) show it requires
neither `cosmic.sandbox.unveil` nor `cosmic.quicksand` — no cycle is
created in either direction.
