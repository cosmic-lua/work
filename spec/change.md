No source file is changed on `main`, and nothing is committed or pushed
in whilp/cosmopolitan. The deliverable is a `## Result` section on this
item and one follow-up item.

1. **Three local `m=rel` runtimes, one whilp/cosmopolitan checkout.**
   Work in a scratch clone or worktree of whilp/cosmopolitan, detached,
   never on a branch that gets pushed. Build each arm and copy the
   resulting APE somewhere stable before building the next, because
   each build overwrites `o/rel/tool/lua/lua`:

   - **arm A**, the parent: check out `8dd093cea`, run
     `make -j$(nproc) m=rel o/rel/tool/lua/lua`, copy the result to
     `/tmp/lua-A`.
   - **arm B**, the suspect: check out `354c17e08`, same build, copy to
     `/tmp/lua-B`.
   - **arm C**, the link-order control: still at `354c17e08`, edit ONLY
     `tool/lua/BUILD.mk`, moving the single line
     `o/$(MODE)/tool/net/llua.o` from its position between `ljson.o`
     and `lsqlite3.o` to the END of the `TOOL_LUA_LUA_MODULES` list.
     Change nothing else — not `tool/net/BUILD.mk`, not a C file, not a
     compiler flag. Rebuild and copy to `/tmp/lua-C`.

   The first build downloads the cosmocc toolchain into `.cosmocc/` and
   needs a network once; the later two are incremental. `sha256sum
   /tmp/lua-A /tmp/lua-B /tmp/lua-C` must print three distinct digests.
   A repeat means an arm did not rebuild and the result is void, which
   is itself the finding to record.

   **If an arm refuses to build**, record the exact failure verbatim as
   a result and drop that arm, keeping A and B — they are the pair the
   reproduction rests on. Do not edit C sources to make an arm build.

2. **Smoke each runtime before measuring it.** For each arm,
   `/tmp/lua-<X> -e 'local cosmo=require("cosmo") local s=("abc"):rep(21845) local e=cosmo.EncodeBase64(s) assert(cosmo.IsBase64(e)) assert(cosmo.DecodeBase64(e)==s) print("ok")'`
   must print `ok`. An arm that does not is dropped as in (1).

3. **Record each arm's base64 layout.** For each arm, from the same
   build's `o/rel/tool/lua/lua.dbg` (copy it beside the APE before
   rebuilding), run `nm o/rel/tool/lua/lua.dbg` and read off the
   addresses of `IsBase64`, `EncodeBase64` and `DecodeBase64`, and of
   `kBase64Alpha`, `kBase64` and any `CHARS` local symbol if the symbol
   table carries them — record `absent` for any it does not, which is a
   legitimate outcome under `-DDWARFLESS` and decides nothing. Also
   record `size o/rel/tool/lua/lua.dbg` and the APE's byte size from
   `wc -c`. This section is DESCRIPTIVE: it is read alongside the
   timings, and no verdict in (6) depends on it.

4. **Three cosmic worktrees, one fixed tree.** From the cosmic
   checkout, make three worktrees detached at **`5ef13f40`**, one per
   arm. In each: `bin/cosmic --make fetch` (this lands the pinned
   cosmos, which is where `zip`/`unzip` come from), then
   `cp /tmp/lua-<X> o/3p/cosmos/lua`, then `bin/cosmic --make build`,
   reading the `build: PASS` verdict line directly and never through a
   pipe. Then `sha256sum o/bin/cosmic` in each: the digests must all
   differ, and a repeat voids the result the same way. Do not edit any
   `.tl` file in any worktree, and do not edit
   `3p/cosmos/cosmos_pin.tl` — the pin stays at `07fc94a1c` in all
   three, because the pin decides nothing once the runtime is
   overwritten and leaving it identical keeps the arms differing by
   exactly one file.

5. **The noise floor, per arm, before any reading.** In each worktree,
   twice:

   ```
   o/bin/cosmic --make run _perf/gate.tl selfcheck \
     o/perf/aa-1.json o/perf/aa-2.json --only codec_base64_roundtrip_64k
   ```

   Record each pass's reported per-scenario delta. `floor` is the
   LARGEST absolute delta any pass on any arm showed.

6. **The readings and the verdict rule — `3ITOUv0w`'s, unchanged.**
   Nine isolated readings per arm, cycling A → B → C → A → … so each
   round samples every arm once; never all of one arm then all of the
   next. Each reading is its own process, run from that arm's worktree
   with the default `--samples`/`--min-secs`:

   ```
   o/bin/cosmic --make run _perf/run.tl --only codec_base64_roundtrip_64k \
     --out o/perf/<arm>-<n>.json
   ```

   Nothing else heavy may run on the machine during the readings.
   Record every reading's µs/op and its reported `±`, in run order.

   For each arm `X`, sort its nine readings ascending as `r1 … r9` and
   take `med(X) = r5`, `lo(X) = r2` (trimmed minimum), `hi(X) = r8`
   (trimmed maximum). Arm `X` reads **SLOWER THAN A** iff all three
   hold: `med(X) > med(A)`; `lo(X) > hi(A)`; and
   `(med(X) - med(A)) / med(A) * 100 > floor`. Otherwise **NOT
   SEPARATED FROM A**. Also record each arm's raw minimum `r1`; it
   decides nothing. Do not change the rule, the reading count or the
   sample settings mid-slice, and do not discard a reading as an
   outlier beyond that trim.

7. **The conclusion is read off this table and nothing else.** Apply
   the rule to B and to C against A, then take the row that matches:

   | B vs A | C vs A | conclusion | follow-up to file |
   |---|---|---|---|
   | SLOWER | NOT SEPARATED | `layout` — the regression is `llua.o`'s link POSITION, not its content; moving one line in `tool/lua/BUILD.mk` restores the base timing | the fix slice in whilp/cosmopolitan, carrying arm C's exact `BUILD.mk` diff and these numbers |
   | SLOWER | SLOWER | `not-link-position` — the slowdown survives an arbitrary link-order perturbation, so it is image growth, heap placement or something the perturbation did not move | a profile slice: `perf record -g` on `o/rel/tool/lua/lua.dbg` for arms A and B on this scenario, comparing where the cycles went |
   | NOT SEPARATED | (either) | `not-reproduced-locally` — the effect does not appear between two single-arch `m=rel` local builds, so it lives in the fat apelink, the release toolchain, or the released-binary instrument | a slice that re-measures the two RELEASED arms on this host with the same rule, to decide whether `3ITOUv0w`'s separation survives a second host before any C change is designed |

   A conclusion of `layout` is a finding about the mechanism, NOT
   permission to land arm C's diff: whether a link-order shuffle is an
   acceptable fix, or whether the base64 loops should instead be made
   layout-insensitive, is a decision for the follow-up's own
   refinement, and this slice does not make it.

8. **Write the result onto this item** with
   `gitboard spec 3ITbccMutXeGIKTxpxTgm8Bgpzy FILE`, run from the `board` worktree. Replace
   the sidecar with the five sections above unchanged plus a sixth,
   `## Result`, appended last — do not delete `## Evidence`. `## Result`
   carries, in this order and in these shapes, because `Acceptance`
   counts them:

   - one line per arm, starting at column 1, spelled exactly
     `- runtime <A|B|C> <64 hex digits>` — the `/tmp/lua-<X>` digest
     from (1);
   - one line per arm, spelled exactly
     `- cosmic <A|B|C> <64 hex digits>` — the `o/bin/cosmic` digest
     from (4);
   - one line per arm, spelled exactly
     `- layout <A|B|C> IsBase64 <addr> EncodeBase64 <addr> DecodeBase64 <addr> text <bytes> ape <bytes>`,
     from (3), each `<addr>` a hex address or `absent`, followed by a
     free-form sentence naming the table symbols found or `absent`;
   - one line per arm, spelled exactly
     `- selfcheck <A|B|C> <pass 1 delta> <pass 2 delta>`, then one line
     spelled exactly `- floor <pct>%` carrying the largest absolute
     delta any pass on any arm showed;
   - the readings as the section's ONLY markdown table, header and rows
     starting at column 1 (`| run | arm | µs/op | ± |`), one row per
     reading, in run order, each row's first cell a two-digit run
     number (`| 01 |`);
   - one line per arm, spelled exactly
     `- stats <A|B|C> min <r1> lo <r2> med <r5> hi <r8>`, in µs;
   - one line per arm other than A, reading
     `B: SLOWER THAN A — med 144.29 → 173.38 µs (+20.16%), trimmed
     ranges disjoint (hi A 146.52 < lo B 171.54), floor 3.2%` or
     `B: NOT SEPARATED FROM A — ...`, with the three numbers the rule
     decided on;
   - one line starting at column 1 spelled exactly
     `mechanism: <layout|not-link-position|not-reproduced-locally>` —
     the (7) row that matched;
   - one line starting at column 1 spelled exactly
     `follow-up: <id>` naming the item filed in (9);
   - one closing paragraph saying what the evidence supports and what
     it does not.

9. **File exactly one follow-up**, with
   `gitboard new "<title>" --parent 3ITVR6Ku --spec-file F`, where F is
   one paragraph of evidence quoting the three arms' medians, the
   trimmed ranges and the floor, and naming the (7) row that chose it.
   Which item to file is the table's last column; file that one and no
   other.
