1. **Arm B and arm A as they are.** In a scratch, detached
   whilp/cosmopolitan checkout at `354c17e08`, keep the existing
   `/tmp/lua-B` and `/tmp/lua-B.dbg` as the unmodified baseline; keep
   `/tmp/lua-A`/`.dbg` for reference only. Rebuild either only if it is
   missing, with `make -j$(nproc) m=rel o/rel/tool/lua/lua`, and record
   the digests either way.

2. **Arm D, the intervention.** Still at `354c17e08`, edit ONLY
   `net/http/isbase64.c`: immediately before the alphabet-scan `while`
   loop (`net/http/isbase64.c:71`, `while (p < pe && (kBase64Alpha[*p & 255] & mask))`), insert

   ```c
   asm volatile(".balign 64");
   ```

   with a comment above it saying that the loop's throughput depends on
   fitting one 64-byte fetch block, that its entry alignment is not the
   lever (`3ITdLKeR`), and that the padding executes once per call
   against an 87 KB scan. Change nothing else — not the other two
   base64 files, not `BUILD.mk`, not a compiler flag, not the loop
   body. Then `rm -f o/rel/net/http/isbase64.o && make -j$(nproc) m=rel
   o/rel/tool/lua/lua`, copy the APE to `/tmp/lua-D` and the `.dbg` to
   `/tmp/lua-D.dbg`.

3. **Verify the loop actually moved, BEFORE timing anything.** With
   `<COSMOCC>/bin/x86_64-linux-cosmo-objdump -d /tmp/lua-D.dbg`, read
   `IsBase64`'s entry address, the scan loop's address (the
   `add $0x1,%rbx` that the later `jne` targets) and that address
   `& 0x3F`, and the loop's byte length up to and including that `jne`.
   The loop reads MOVED iff `loop_address & 0x3F` plus the loop length
   is at most 64 — that is, the loop lies inside one 64-byte block.

   **If the loop did NOT move**, that is the result: record the three
   levers now ruled out (the two in `## Evidence` plus this one) with
   their disassembly, skip (4) and (5) entirely, and file the follow-up
   in (6) that the `not-moved` row names. Do not try a fourth lever —
   choosing one is a `plan` decision, and this spec fixes exactly one.

4. **Correctness, before performance.** `make -j$(nproc)
   o//tool/lua/test` in the same checkout, read directly and never
   through a pipe — the repo's stated gate
   (whilp/cosmopolitan `AGENTS.md`, "Conventions"). It builds default
   mode, so it is a cold build the first time. Also smoke arm D:
   `/tmp/lua-D -e 'local cosmo=require("cosmo") local s=("abc"):rep(21845) local e=cosmo.EncodeBase64(s) assert(cosmo.IsBase64(e)) assert(cosmo.DecodeBase64(e)==s) print("ok")'`
   must print `ok`.

5. **The readings: NINE per arm, round-robin, B and D only.** Cycle
   B → D → B → D → …; each reading is its own process,
   `/tmp/lua-<X> /tmp/b64split.lua <X>`, with `/tmp/b64split.lua` the
   script `3ITdLKeR`'s `## Change` (2) fixes verbatim — do not edit it.
   Nothing else heavy may run on the machine during the readings.
   Record all four columns from every reading, in run order.

   Apply `3ITdLKeR`'s rule to the `is` and `roundtrip` columns: sort
   each arm's nine values as `r1 … r9`, take `med = r5`, `lo = r2`,
   `hi = r8`. A column reads **RECOVERED** iff `med(D) < med(B)`,
   `hi(D) < lo(B)`, and `(med(B) - med(D)) / med(B) * 100 > 3.7`.
   Otherwise **NOT RECOVERED**. Do not change the rule, the reading
   count or the script mid-slice.

   Also state, as prose and deciding nothing, how `med(D)`'s `is`
   column compares with the 27.137 µs `3ITdLKeR` measured for arm A —
   whether the intervention reached the fast arm's timing, fell short,
   or passed it.

6. **The conclusion is read off this table and nothing else.**

   | loop moved | `is` | conclusion | what to do |
   |---|---|---|---|
   | no | — | `no-lever` — inline `.balign` did not move the loop either | file a slice for the next lever, naming all three ruled out; open no PR |
   | yes | RECOVERED | `confirmed` — fetch-block straddling is the cause and pinning the loop fixes it | open the PR in (7), then file nothing |
   | yes | NOT RECOVERED | `moved-not-fixed` — the loop no longer straddles and the timing did not follow, so straddling is not the whole cause | file a slice that returns to mechanism, carrying this negative; open no PR |

7. **Only on `confirmed`, open ONE PR in whilp/cosmopolitan** carrying
   the `net/http/isbase64.c` diff and nothing else, its body quoting
   the before/after `is` medians, both trimmed ranges, the floor, and
   the before/after loop addresses and `& 0x3F` values from (3). Say in
   it that PR #280 aligns the entry rather than the loop and is
   superseded by this — do not close #280 yourself; that is its
   author's call. Hand this item over with
   `gitboard move 3ITerUZf check --pr N`.

8. **Write the result onto this item** with
   `gitboard spec 3ITerUZf FILE`, run from the `board` worktree, in
   every case including `no-lever`. Replace the sidecar with the five
   sections above unchanged plus a sixth, `## Result`, appended last —
   do not delete `## Evidence`. `## Result` carries, in this order and
   in these shapes, because `Acceptance` counts them:

   - one line per arm built or reused, starting at column 1, spelled
     exactly `- runtime <B|D> <64 hex digits>`;
   - one line per arm, spelled exactly
     `- disasm <B|D> IsBase64 start <hex> loop <hex> loop%64 <n> looplen <bytes>`,
     from (3);
   - one line spelled exactly `- loop <moved|not-moved>`;
   - when the loop moved: one line spelled exactly
     `- tests o//tool/lua/test <PASS|FAIL>` and one spelled exactly
     `- smoke D <ok|FAIL>`, from (4);
   - when the loop moved: the readings as the section's ONLY markdown
     table, header and rows starting at column 1
     (`| run | arm | encode | is | decode | roundtrip |`), one row per
     reading in run order, each row's first cell a two-digit run
     number;
   - when the loop moved: one line per arm per column, spelled exactly
     `- stats <B|D> <is|roundtrip> min <r1> lo <r2> med <r5> hi <r8>`
     — four lines;
   - when the loop moved: one line per column, spelled exactly
     `is: RECOVERED — med 52.445 → 27.900 µs (-46.80%), trimmed ranges
     disjoint (hi D 28.100 < lo B 52.238), floor 3.7%` or
     `is: NOT RECOVERED — ...`, and the same for `roundtrip` — two
     lines;
   - one line starting at column 1 spelled exactly
     `mechanism: <no-lever|confirmed|moved-not-fixed>`;
   - one line starting at column 1 spelled exactly `pr: <N>` on
     `confirmed`, or `pr: none` otherwise;
   - one line starting at column 1 spelled exactly
     `follow-up: <id>` on `no-lever` or `moved-not-fixed`, or
     `follow-up: none` on `confirmed`;
   - one closing paragraph saying what the evidence supports and what
     it does not.
