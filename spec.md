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
independent end-to-end verification. All four chunks are implemented and
validated and have landed through their normal protected merges. The measured implementation
record below supersedes the original scouting estimate.

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

## Implemented outcome and independent verification

The entire four-chunk implementation is complete and independently accepted:

1. Compatibility matrix/corpus [cosmopolitan PR393](https://github.com/cosmic-lua/cosmopolitan/pull/393),
   landed6c32f7a07cb7272300b2e06e06ac9db85360e024.
2. Checked JSON benchmarks [cosmic PR1836](https://github.com/cosmic-lua/cosmic/pull/1836),
   landedc9cdb84211b00239dfc88d3331fe2785d33800a0.
3. Bounded C fast path [cosmopolitan PR394](https://github.com/cosmic-lua/cosmopolitan/pull/394),
   landed780f45055acd52401de6c95c16365338690e19e7.
4. Actual released runtime pin [cosmic PR1837](https://github.com/cosmic-lua/cosmic/pull/1837),
   accepted7dfa1dd07901d6411c896a017a245e2a9230c0d7,
   landeda327ff32760ec15bbde7514c1cd7ed34647ae8d7.

The C diff uses the fixed bounded scalar algorithm above and leaves the
fallback loop unchanged. All four external call sites, stack ownership,
return pointer and initialized-buffer cleanup were independently reviewed.
Both clean C binding suites and rel builds pass. Baseline/candidate/UBSan
corpora match exactly; GC ownership stress passes. A compiled p+1→p mutant
fails the new compatibility assertion, then exact restoration/rebuild passes.
The controlled same-mode local C experiment passes the full performance gate:
long-ASCII time-73.4%, large JSON-26.1%, short ASCII-42.5%, both fallbacks improve.
Its source identities, commands, flags, binary hashes and full evidence are
recorded in child a6Gm_olvM, including successful runs34678285918/34679751184.

The real release2026.09.12-780f45055 is proven by successful exact-source
[release run34696571862](https://github.com/cosmic-lua/cosmopolitan/actions/runs/34696571862),
not by a tag target alone. Independently downloaded cosmos.zip SHA256 is
15e2703e0c6893299f0468a16bb9e9b4e13d87c492053013b0dc3daaa9003ea1;
raw Lua SHA256 e757d78685b3549a3a061ebda49d20855e3c2979fbd4e62e321a6f438d6884f3.
The final pin changes only version+digest; definitions/public declarations
are unchanged. Independent real wrong-digest fetch mutations fail and
restored exact pins pass.

Root ran the entire packaged outcome through
[successful experiment34698381287](https://github.com/cosmic-lua/cosmic/actions/runs/34698381287),
using the actual old pinned release2026.09.06-e748d6a1e and actual new
release beneath the same Cosmic7dfa1dd0 source and byte-identical payload.
An independent fresh-context reviewer checked both the results and the
measurement controls. All36,895 raw-runtime corpus records compare equal,
SHA256 e61139f10a9dbced988b9cd6721959a585db24d3e2d2efc18b5d60512d496048;
both GC probes pass128 iterations/8 retained values, on Linux and macOS.
Candidate full Linux CI passes3,549 tests,318 coverage files and5 stages.
All3 JSON fuzz properties pass50,000 iterations each, seed34698381287.
The required CI/build/repro/macOS/Windows PR gates all pass too.

Four adjacent actual-package A/B pairs show long-ASCII decode time reduced
86.2–86.4% (about169us→23us), large JSON25.2–30.1%, short ASCII48.8–55.2%,
escaped fallback72.9–73.3%, and UTF-8 fallback63.8–64.8%. The initial full
53-scenario readings and spreads are recorded unchanged in child p8Ct_8YDi.
The full gate exits0 with `perf-compare: PASS`:0 regressions,7 faster,46 ok.
It preserves initial HTTP timing flags until baseline retries and an extra
same-candidate control establish noise. All original/retry/median/self-check
files are retained separately; no test, scenario or threshold was weakened.
These are measured packaged results, distinct from the controlled local-C
measurements and the superseded5–10% historical hypothesis.

The experiment took30m17s and remained active: about11m30s builds/correctness,
8m39s rebuild+4JSONpairs,5m22s fullinitialcomparison and4m38s noisecontrols.
A prior run failed only collecting a temporary test directory after all
correctness passed; the runner collector was fixed and the complete final
experiment reran. Temporary validation branches were removed after local
artifacts and commits were retained. No runner infrastructure enters either
product. Final landing and parent-level merged-artifact verification follow.

## Final parent-level outcome verification

All four implementation PRs have landed. Final pin PR1837 merged at
2026-09-12T15:17:42Z as a327ff32760ec15bbde7514c1cd7ed34647ae8d7;
local cosmic/main is that exact commit. Root verified the entire landed
tree equals the accepted7dfa1dd0 tree and main pins the proven new release.
The integration build's downloaded Cosmic artifact is byte-identical to
the candidate in the successful full packaged performance experiment,
SHA25626b019456bfd33bfa8e5624fd957353e8db7411a67a4a23836d5ff9ce1d7a313.

Root directly executed this actual integrated Cosmic artifact on macOS
arm64 through the36,895-record frozen corpus and compared every record
to the old package oracle: zero mismatches, exit0, SHA256e61139f1 (full
hash above). The same artifact passes the dynamic GC ownership probe,
128 iterations/8 retained values, exit0. This checks the delivered runtime
rather than only relying on child completion states. Raw parent-level
proof is local json-evidence/integration-artifact-34701499547; full measured
performance and correctness proof remains in experiment34698381287 and
child p8Ct_8YDi. No implementation chunk remains outstanding.

Final protected integration run34701499547 passes all5 jobs, including
reproducibility and both platform smoke checks. The complete optimization
meets the stated outcome with no unresolved acceptance gate.
