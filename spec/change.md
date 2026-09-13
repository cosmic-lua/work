No source file is changed on `main`, and nothing is committed or
pushed in whilp/cosmopolitan. The deliverable is a `## Result` section
on this item and one follow-up item.

1. **Two local `m=rel` runtimes.** Only arms A (`8dd093cea`) and B
   (`354c17e08`); arm C is dropped, proven null by `3ITbccMu`. If
   `/tmp/lua-A` and `/tmp/lua-B` still exist from that slice with the
   digests quoted in `## Evidence`, reuse them. Otherwise rebuild in a
   scratch, detached whilp/cosmopolitan checkout with
   `make -j$(nproc) m=rel o/rel/tool/lua/lua` at each commit, copying
   `o/rel/tool/lua/lua` to `/tmp/lua-<X>` and `o/rel/tool/lua/lua.dbg`
   to `/tmp/lua-<X>.dbg` before building the next. Record both APE
   digests either way. They must differ from each other.

2. **The split script, verbatim.** Write exactly this to
   `/tmp/b64split.lua`. Do not change `N`, `SAMPLES`, the warm-up, the
   estimator or the blob; they are this spec's decisions.

   ```lua
   local cosmo = require("cosmo")
   local unix = require("unix")
   local MONO = unix.CLOCK_MONOTONIC
   local N = 500
   local SAMPLES = 7

   local function now_ns()
     local s, ns = unix.clock_gettime(MONO)
     return s * 1000000000 + ns
   end

   local parts = {}
   for i = 1, 1024 do
     parts[i] = string.format(
       "record %04d: the quick brown fox jumps over the lazy dog %d\n",
       i, i * 37)
   end
   local BLOB = table.concat(parts)
   local ENC = cosmo.EncodeBase64(BLOB)
   assert(cosmo.IsBase64(ENC))
   assert(cosmo.DecodeBase64(ENC) == BLOB)

   local function time_call(fn)
     fn(); fn(); fn()
     local best = math.huge
     for _ = 1, SAMPLES do
       collectgarbage("collect")
       local t0 = now_ns()
       for _ = 1, N do fn() end
       local dt = (now_ns() - t0) / N
       if dt < best then best = dt end
     end
     return best / 1000.0
   end

   local enc = time_call(function() return cosmo.EncodeBase64(BLOB) end)
   local isb = time_call(function() return cosmo.IsBase64(ENC) end)
   local dec = time_call(function() return cosmo.DecodeBase64(ENC) end)
   local all = time_call(function()
     local e = cosmo.EncodeBase64(BLOB)
     if cosmo.IsBase64(e) then return cosmo.DecodeBase64(e) end
   end)

   print(string.format(
     "%s encode %.3f is %.3f decode %.3f roundtrip %.3f sum %.3f",
     arg[1] or "?", enc, isb, dec, all, enc + isb + dec))
   ```

   The three `assert`s are the correctness net: an arm whose base64 no
   longer round-trips fails here rather than producing a number.

3. **The readings: NINE per arm, round-robin.** Cycle A → B → A → B → …
   so each round samples both arms; never all of one arm then the
   other. Each reading is its own process:
   `/tmp/lua-<X> /tmp/b64split.lua <X>`. Nothing else heavy may run on
   the machine during the readings. Record all four numbers from every
   reading, in run order.

4. **The verdict rule — `3ITbccMu`'s, per column.** For each of the
   four columns (`encode`, `is`, `decode`, `roundtrip`) and each arm,
   sort that arm's nine values ascending as `r1 … r9` and take
   `med = r5`, `lo = r2`, `hi = r8`. A column reads **MOVED** iff all
   three hold: `med(B) > med(A)`; `lo(B) > hi(A)`; and
   `(med(B) - med(A)) / med(A) * 100 > 3.7` — the floor `3.7%` is
   `3ITbccMu`'s, carried over rather than re-measured, because this
   instrument's own repeatability is exercised by the seven-sample
   minimum inside every reading. Otherwise **NOT MOVED**. Do not change
   the rule, the reading count or the script mid-slice, and do not
   discard a reading as an outlier beyond that trim.

5. **The conclusion is read off this table and nothing else.** Apply
   (4) to each of `encode`, `is` and `decode`, then take the first row
   that matches, reading top to bottom:

   | `roundtrip` | `is` | other two | conclusion | follow-up to file |
   |---|---|---|---|---|
   | NOT MOVED | (any) | (any) | `not-in-this-instrument` — the raw-lua split does not see the regression the cosmic harness sees, so the delta is not in these three calls as called here | a slice that re-cuts the instrument, naming what the cosmic harness does that this script does not (payload, zipos, the Teal wrapper frames) |
   | MOVED | MOVED | both MOVED | `broad` — every part moved, including the one that allocates nothing, so it is a whole-image effect rather than one loop | a slice that tests image size directly: pad arm A's `.text` by `llua.o`'s size with dead code and see whether A alone moves to B's timing |
   | MOVED | MOVED | neither or one | `scan-loop-layout` — the pure-scan, zero-allocation call moved, so it is compiled-code placement | a slice that reads `IsBase64`'s disassembly in both arms and tests an alignment intervention on it |
   | MOVED | NOT MOVED | at least one MOVED | `allocation-path` — only the allocating calls moved, so it is the heap or the allocator under a bigger image, not the scan loops | a slice that instruments `malloc`/`realloc` placement across the two arms rather than the base64 code |
   | MOVED | NOT MOVED | neither | `unattributed` — the whole moved but no part did, which the sum line should already have flagged | a slice that re-cuts the instrument, as the first row |

   A conclusion here names a mechanism, NOT a fix: which intervention
   to make in whilp/cosmopolitan is the follow-up's own refinement, and
   this slice does not choose one.

6. **Record the disassembly of whichever call carries the delta**, and
   only that one — or of `IsBase64` when the row is `broad`, and of
   none when `roundtrip` is NOT MOVED. For each arm, with
   `<COSMOCC>/bin/x86_64-linux-cosmo-objdump -d /tmp/lua-<X>.dbg`,
   record that function's start address, its byte length (next symbol's
   address minus its own), its start address modulo 64, and the
   address modulo 64 of the target of its innermost backward branch —
   the loop head. Six numbers per arm. This section is DESCRIPTIVE: no
   verdict in (5) depends on it.

7. **Write the result onto this item** with
   `gitboard spec 3ITdLKeR FILE`, run from the `board` worktree.
   Replace the sidecar with the five sections above unchanged plus a
   sixth, `## Result`, appended last — do not delete `## Evidence`.
   `## Result` carries, in this order and in these shapes, because
   `Acceptance` counts them:

   - one line per arm, starting at column 1, spelled exactly
     `- runtime <A|B> <64 hex digits>` — the `/tmp/lua-<X>` digest from
     (1);
   - the readings as the section's ONLY markdown table, header and rows
     starting at column 1
     (`| run | arm | encode | is | decode | roundtrip |`), one row per
     reading, in run order, each row's first cell a two-digit run
     number (`| 01 |`), all four values in µs;
   - one line per arm per column, spelled exactly
     `- stats <A|B> <encode|is|decode|roundtrip> min <r1> lo <r2> med <r5> hi <r8>`,
     in µs — eight lines;
   - one line per column, spelled exactly
     `encode: MOVED — med 41.20 → 47.90 µs (+16.26%), trimmed ranges
     disjoint (hi A 42.10 < lo B 47.30), floor 3.7%` or
     `encode: NOT MOVED — ...`, with the three numbers the rule decided
     on — four lines, one each for `encode`, `is`, `decode` and
     `roundtrip`;
   - one line per arm, spelled exactly
     `- disasm <A|B> <function> start <hex> len <bytes> start%64 <n> loop%64 <n>`
     from (6), or the single line `- disasm none` when (6) says to
     record none;
   - one line starting at column 1 spelled exactly
     `mechanism: <not-in-this-instrument|broad|scan-loop-layout|allocation-path|unattributed>`
     — the (5) row that matched;
   - one line starting at column 1 spelled exactly
     `follow-up: <id>` naming the item filed in (8);
   - one closing paragraph saying what the evidence supports and what
     it does not, including whether the three parts' sum tracks the
     measured `roundtrip` on each arm.

8. **File exactly one follow-up**, with
   `gitboard new "<title>" --parent 3ITVR6Ku --spec-file F`, where F is
   one paragraph of evidence quoting both arms' per-column medians, the
   trimmed ranges and the floor, and naming the (5) row that chose it.
   Which item to file is the table's last column; file that one and no
   other. If the host it would run on lacks a tool that item needs,
   say so in that paragraph rather than filing a spec that cannot run —
   which is what `3ITbccMu` did about `perf`.
