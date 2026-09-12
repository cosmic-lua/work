## Change

Accelerate JSON strings containing only the decoder's ASCII class with
a bounded prefix scan and direct `lua_pushlstring` when the scan reaches
the closing quote. Preserve the existing buffered string parser for all
other inputs, feeding it the already-scanned prefix without rescanning.
This targets cosmic's `json_decode_large` and long string workloads via
cosmo.DecodeJson. No SIMD, word loads, parser replacement, public surface
change, UTF-8 repair, or changes to the old fallback's ASCII loop.

Four dependency-ordered children cover compatibility tests, checked
performance scenarios, the C fast path, and the released cosmic pin plus
independent end-to-end verification. This is a design, not an implemented
optimization. The item keeps its existing priority under G6.

Implementation order (each earlier item is a prerequisite child of the next):

1. [Compatibility matrix and differential corpus](https://github.com/cosmic-lua/work/blob/items/3JDHcdRYLy1FFN57VNbZoH1ElpH/spec.md)
2. [Checked string benchmarks](https://github.com/cosmic-lua/work/blob/items/3JDHcYe1whiQnoUvqfAEw74nBaa/spec.md)
3. [Bounded C fast path](https://github.com/cosmic-lua/work/blob/items/3JDHcUarYJewnEbR6YEa6GmolvM/spec.md)
4. [Release pin and final verification](https://github.com/cosmic-lua/work/blob/items/3JDHcRko4zUF2e7DYHBp8Ct8YDi/spec.md)

## Access

cosmic-lua/cosmopolitan, master: tool/net/ljson.c and tool/lua tests.
cosmic-lua/cosmic, main: benchmarks and final runtime pin.
cosmic-lua/work: specifications and durable measurement evidence.
Provide this parent and the relevant child to each implementation agent.

## Source evidence

Examined cosmic b0ab4e8fe2bb798296e68e96ae640f82c8c03c5f and cosmopolitan
e748d6a1e40e6419a48f16a9626c287014bdb6b5. Reproduce with:

Both snapshots matched the live remote main/master heads when checked
with `git ls-remote origin refs/heads/main` and
`git ls-remote origin refs/heads/master` immediately before publication.

```
rg -n 'case.*string|luaL_buffinit|case ASCII|case DQUOTE|StringFailureWithReason' tool/net/ljson.c
sed -n '323,346p' tool/net/ljson.c
sed -n '45,82p' tool/lua/lcosmo.c
```

At ljson.c:323 (`case '"':  // string`), the context refusal runs first,
then luaL_buffinit and a byte-at-a-time dispatch. ASCII calls luaL_addchar;
the quote pushes the buffer result. kJsonStr at :61 classifies exactly
0x20 through 0x7f except quote/backslash as ASCII. Do not substitute
isprint/isascii, locale-sensitive classification, or signed char indexes.
LuaDecodeJson at tool/lua/lcosmo.c:45 retains the input Lua string on its
stack and calls DecodeJsonEx again after the first result to detect junk.
The fast path must return the pointer AFTER the quote, not the quote or
end of input, and preserve one pushed value just like the old parser.

cosmic/_perf/bench/json_bench.tl exercises wrappers on 1000 short-string
records plus small decode/roundtrip and encode; add targeted checked
scenarios rather than altering those existing workloads. The old capture's
929 microseconds and 5–10% predicted win are historical scouting, not a
current baseline or a promised result.

## Executed scouting, 2026-09-11 local date

macOS arm64; runtime cosmic-lua 2026-09-10-851d5ec, cosmos
2026.09.06-e748d6a1e; binary SHA256
10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2.
An unmodified cosmo.DecodeJson probe, five CPU-time samples, loop result
length asserted, gave:

| ASCII content bytes | Median us/decode | Min–max |
|---:|---:|---:|
| 0 | 0.081 | 0.080–0.082 |
| 8 | 0.094 | 0.094–0.096 |
| 64 | 0.195 | 0.192–0.199 |
| 1024 | 1.898 | 1.889–1.903 |
| 65536 | 117.150 | 116.870–117.420 |

This includes Lua loop/assert overhead; it is neither a harness A/B nor
proof of gain. It establishes a size-scaling workload to measure correctly.
Actual boundary probe output (hex represents returned string bytes):

```
DEL: hex=617f62
C0: error=non-del c0 control code in string
C1: error=c1 control code in string
CESU8: error=illegal utf-8 character
lone surrogate escape: hex=5c7564383030
printable hex escape: hex=41
unterminated: error=unexpected eof in string
```

Inputs respectively: quoted a/0x7f/b; quoted a/0x00/b; quoted a/0x80/b;
quoted bytes ED AE 80 ED B0 80; `"\ud800"`; `"\x41"`; unterminated `"abc`.
In particular, the old capture's claim that CESU-8 is successfully merged
is not established by this sample: the actual decoder refused it. Keep
every >=0x80 byte on the existing parser; do not silently fix that behavior
in a performance patch. Any Unicode correctness repair is separate work.

## Fixed algorithm

In the existing string case, AFTER the context check and BEFORE buffer
initialization:

1. Save `string_start = p` (p already points past the opening quote).
2. While `p < e` and `kJsonStr[(unsigned char)*p] == ASCII`, increment p.
   The bound must be tested BEFORE dereferencing. Use scalar loads only.
3. If `p < e && *p == '"'`, call
   `lua_pushlstring(L, string_start, p - string_start)` and return
   `(struct DecodeJson){1, p + 1}`. This includes an empty string.
   Do not initialize or finalize a luaL_Buffer on this branch.
4. Otherwise initialize b using the existing luaL_buffinit. If the prefix
   is nonempty, append it once with luaL_addlstring. Continue the existing
   loop with p still pointing at the exceptional byte or e; do not consume
   it and do not reset p. All labels that finalize b remain reachable only
   AFTER buffer initialization. EOF goes through the old error path.
5. Leave the entire existing switch/escape/Unicode logic intact, including
   its ASCII fallback arm. Do not resume prefix scanning after an escape
   in this change. No new threshold or special case for short strings.

Declare the extra pointer locally without disturbing the number parser's
`a` pointer or introducing VLA/goto lifetime hazards. The input is borrowed
only for this call; pushlstring owns its result through Lua. No raw malloc,
static scratch storage, retained input pointer, additional stack slot,
registry/cache, or new function parameter is needed. Inspect all callers
of DecodeJson/DecodeJsonEx before landing, including C callers using an
explicit length. Never depend on a NUL terminator, including at e.

This remains O(input bytes); the all-ASCII path avoids buffer construction
and its per-byte append/copy work. Fallback prefixes are scanned once and
appended once; a short or empty prefix must not cause a second traversal.
Long fallback strings still use the existing buffer ownership and cleanup.
OOM allocation timing may differ, but no new leaks, invalid cleanup or
unbounded memory are acceptable. Ordinary parse return shapes/errors and
all successful values remain identical.

## Test specification

- Complete plain ASCII strings of lengths 0,1,2,7,8,15,16,31,32,63,64,
  1023,1024,1025 and 65536; cover all allowed ASCII bytes including DEL.
  Raw quote and backslash are boundaries, never copied as ordinary bytes.
- Every byte 0..255 at beginning, middle and end of a string, preceded by
  prefixes of length 0,1,15,16,1023,1024,1025. Freeze old outputs or exact
  errors before implementation. This is a bounded generated matrix, not
  a hand-written guess that the decoder implements a different standard.
- Every JSON escape; the accepted printable \x extension and refused
  nonprintable/invalid hex; embedded escaped NUL; valid UTF-8 of 2/3/4
  bytes; malformed/overlong/truncated sequences; surrogate escape pairs,
  lone escapes, raw surrogate encodings and CESU-like byte sequences.
  Baseline behavior is the oracle even when surprising.
- EOF at every prefix length, trailing backslash, truncated unicode escape,
  unterminated raw Unicode, and a quote followed by whitespace or junk.
  Assert exact error text and number of Lua returns. Do not conflate nil,
  false and an empty string. Use table.pack for return arity.
- Place strings as top-level values, array elements, object values and
  object keys. Include duplicate keys, malformed comma/colon contexts,
  null sentinel options, empty arrays/objects, and repeated calls following
  both success and failure. Fast strings must not bypass structural checks.
- Force normal Lua garbage collections between batches; returned strings
  stay valid after the input reference is dropped. Run existing JSONTestSuite
  and annotation ratchets with all binding tests.
- Differential-run a deterministic corpus on unmodified and changed LOCAL
  C runtimes: identical case ids, return arities, exact error strings, and
  typed value fingerprints. Strings and keys fingerprint as byte hex,
  object entries sort by encoded key, distinguish array markers, null
  sentinel identity, booleans and numbers. Compare every record, not an
  aggregate hash alone. No second decoder shipped in production.

Bounds review is required at both scalar reads. Use existing sanitizer
facilities where available; this task does not depend on the separate
UBSan CI rollout. Do not claim Lua strings' trailing NUL alone proves
length-safe C reads. No vectorized or word-at-a-time loads are in scope.

## Performance acceptance and release

Baseline on Linux from the unmodified LOCAL cosmopolitan tree after tests
land. Clean builds eliminate the old stale-header-dependency concern.
Follow cosmic/skills/optimize/cosmopolitan.md: `make -j$(nproc)
o//tool/lua/lua` and `make -j$(nproc) o//tool/lua/test`; compare same build
mode on both sides, and confirm final gains on rel-versus-rel before
shipping. Embed the SAME cosmic source and benchmark payload onto each
local runtime via o/3p/cosmos/lua and require build: PASS. Record source
SHAs, build flags, runtime and assembled-binary hashes; --version reads a
pin stamp and is insufficient proof of subject identity.

Use explicit built binaries with --make run for the harness. Capture full
baseline/current files separately, then run `_perf/gate.tl compare BASE
CURRENT SELFB`, with SELFB distinct from both input files. Require exit 0
and `perf-compare: PASS`, candidate `--make ci`, exact differential equality,
and a target improvement above noise on the added long-ASCII scenario.
The existing json_decode_large must not reproducibly regress; record its
actual delta even if smaller than noise. Short-string, escaped and UTF-8
scenarios must not reproducibly regress either. A long-string win alone
cannot excuse slower common short strings. For <10% effects and surviving
flags, use the optimize skill's interleaving/cross-session procedure.
Do not change workloads, check functions, thresholds, or gates to pass.

If the target does not improve or regressions survive, do not ship the
optimization: record the rejected hypothesis and data. Otherwise land the
C change, wait for its actual release artifact, verify its provenance,
update cosmic's real version+digest pin, regenerate through normal build
and repeat final gates on the packaged runtime. Never invent a future tag
or digest. definitions.lua and existing public signatures remain unchanged.
All performance findings stay on the board/local o/, not committed docs.

## Historical context

Original August scouting proposed ~5–10% on json_decode_large and located
the same per-byte string loop. This refinement chooses one concrete direct
string path, supplies compatibility tests and actual build/release gates,
and supersedes the earlier open choice between pushlstring/addlstring.

## Reproduction and verification performed during refinement

`sh cosmic/o/bootstrap/cosmic cosmopolitan/tool/lua/test_ljson.lua`
completed with exit 0 against the identified runtime. This is the existing
Lua test file on macOS, not a rebuilt C binary or the full Linux gate.
No optimized variant was written or measured.

`wc -l tool/lua/test_ljson.lua` in cosmopolitan printed 231;
`wc -l _perf/bench/json_bench.tl` in cosmic printed 136.
`rg -n 'test_ljson|TOOL_LUA_TESTS' tool/lua/BUILD.mk` showed explicit .ok
recipes and the TOOL_LUA_TESTS aggregate, including test_ljson at line507.
New files require explicit test enrollment/normal discovery as specified;
no public signature or annotation ratchet row changes.

Save this executed script as json_design_probe.lua beside the cosmic
checkout and run `sh cosmic/o/bootstrap/cosmic json_design_probe.lua` with
that identified runtime to reproduce the scouting procedure:

```lua
local cosmo=require('cosmo')
local decode=cosmo.DecodeJson
local function hex(s)
  return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end))
end
for _,case in ipairs({
  {'DEL','"a'..string.char(127)..'b"'},
  {'C0','"a'..string.char(0)..'b"'},
  {'C1','"a'..string.char(128)..'b"'},
  {'CESU8','"'..string.char(0xed,0xae,0x80,0xed,0xb0,0x80)..'"'},
  {'lone surrogate escape','"\\ud800"'},
  {'printable hex escape','"\\x41"'},
  {'unterminated','"abc'},
}) do
  local v,e=decode(case[2])
  print(case[1]..': '..(v and ('hex='..hex(v)) or ('error='..tostring(e))))
end
for _,n in ipairs({0,8,64,1024,65536}) do
  local data='"'..string.rep('a',n)..'"'
  local count=math.max(100,math.floor(2000000/math.max(n,1)))
  local samples={}
  for j=1,5 do
    local start=os.clock()
    for i=1,count do assert(#assert(decode(data))==n) end
    samples[j]=(os.clock()-start)*1e6/count
  end
  table.sort(samples)
  print(string.format('ascii bytes=%d median=%.3fus range=%.3f..%.3f',n,samples[3],samples[1],samples[5]))
end
```
