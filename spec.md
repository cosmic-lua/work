## Change

Pin the verified released C optimization in cosmic and independently
verify the packaged result. The nested C implementation must have landed
and passed its local correctness/performance gates. Ready only when an
actual cosmic-lua/cosmopolitan release artifact can be traced to the
landed commit; record the release's source SHA, URL and SHA256 first.
Do not guess a future version or use a release tag's commit as a substitute
for proof of the binary's build source.

## Access

cosmic-lua/cosmic (main), cosmic-lua/cosmopolitan (release provenance),
cosmic-lua/work. Parent Ev3f_N6gu defines all acceptance criteria.

## Implementation

Update the real version/digest fields in `3p/cosmos/cosmos_pin.tl` using
the artifact verified above and normal fetch/build workflow. Run normal
type generation; definitions.lua and the public surface are unchanged,
so unexpected declaration churn must be explained before proceeding.
Do not hand-edit generated declarations or update unrelated pins.
Use the same cosmic payload and benchmark tree on baseline and candidate
for the final comparison; identify the embedded runtime by artifact
provenance and hashes, never --version alone.

## Verification

Run candidate --make ci, existing cosmic JSON fuzz/roundtrip suites and
the full checked perf harness. Run the child one's differential corpus
against baseline/candidate raw runtimes too. Record exact commands,
zero differential mismatches, exit statuses, source/binary hashes,
json_decode_large plus all four new rows, spreads and gate verdict.
`_perf/gate.tl compare BASE CURRENT SELFB` must exit 0 and print
`perf-compare: PASS`; SELFB and retry files must not overwrite baseline.
No target or existing scenario may be renamed, weakened or removed.

Only finish after the long-ASCII gain exceeds noise, common short strings
and fallback scenarios have no reproducible regression, packaged-runtime
correctness passes and the pin PR lands. A failed check requires repair
or rejection, not a completion with caveats. This is the final handoff:
quote actual measured gains rather than the old 5–10% estimate. Findings
stay on the board; raw files remain local artifacts, not product docs.

Release readiness check: after recording LANDED_SHA from the C merge,
run `gh run list --repo cosmic-lua/cosmopolitan --workflow release.yml
--commit "$LANDED_SHA" --status success --json databaseId,headSha,conclusion`.
A row with headSha equal to LANDED_SHA and conclusion success establishes
that source's completed release workflow; an empty list means not ready.
Read that run's generated release tag and asset publication, download its
cosmos.zip and SHA256SUMS, and independently verify the archive digest.
The inspected workflow builds the checked-out HEAD and generates the tag
from it; do not use the moving latest tag. If release workflow/provenance
changes, refresh the evidence rather than presuming these facts still hold.

## Verified release readiness

The C prerequisite is complete. PR394 landed as
780f45055acd52401de6c95c16365338690e19e7; its full local correctness,
rel performance and protected merge-queue gates passed (see child a6Gm_olvM).
[Release run34696571862](https://github.com/cosmic-lua/cosmopolitan/actions/runs/34696571862)
completed successfully with headSha exactly equal to that landed commit.
Its checkout log confirms the full source SHA and its publication step
names the actual tag 2026.09.12-780f45055, published 2026-09-12T13:37:00Z.

Use these independently verified values for the two pin fields:

- Version: `2026.09.12-780f45055`.
- Archive URL: https://github.com/cosmic-lua/cosmopolitan/releases/download/2026.09.12-780f45055/cosmos.zip
- Archive SHA256: `15e2703e0c6893299f0468a16bb9e9b4e13d87c492053013b0dc3daaa9003ea1`.
- Extracted raw Lua SHA256: `e757d78685b3549a3a061ebda49d20855e3c2979fbd4e62e321a6f438d6884f3`.

The downloaded archive and extracted Lua match both SHA256SUMS and their
GitHub asset digests. The inspected release workflow builds checked-out
HEAD, links rel x86_64/aarch64 into the fat runtime, and publishes that
generated tag. Source provenance is established by the successful build
run, not merely the tag target.

Final comparison control remains the current old pin:
source e748d6a1e40e6419a48f16a9626c287014bdb6b5, successful release
run34019530758, version 2026.09.06-e748d6a1e,
archive https://github.com/cosmic-lua/cosmopolitan/releases/download/2026.09.06-e748d6a1e/cosmos.zip,
SHA256 b7422e52cd83bbded46cc9e55945834ddbb18b6c7c5c98767fd6b1dda1fb8ee7,
raw Lua SHA256 464d5e80295af94e1e02c022b10ed165d9203adb7b49fa6c913541dc39453a76.
Its archive and manifest were also independently downloaded and verified.

## Completed packaged validation

Exact pin candidate: 7dfa1dd07901d6411c896a017a245e2a9230c0d7,
[PR1837](https://github.com/cosmic-lua/cosmic/pull/1837).
Only the version and archive digest change. Normal fetch/build/type
generation pass with no tracked declaration churn. Builder and independent
reviewer each changed the digest to a different valid 64-hex value: normal
`bin/cosmic --make fetch 3p/cosmos/cosmos_pin.tl` refused with the expected
want/got SHA mismatch. Both restored the exact committed file and obtained
fetch/build success and clean status. Focused JSON tests also pass.

[Final package run34698381287](https://github.com/cosmic-lua/cosmic/actions/runs/34698381287)
completed successfully on Linux x86_64, kernel6.17.0-1022-azure, 4 CPUs,
pinned buildpack-deps noble image
sha256:cfb30ff3856780c63b00ec3ad2e4aed77ae6afce5975ebb8ad9525ec45354e2e.
Both subjects use exact Cosmic7dfa1dd0 and the same source/benchmark payload,
built at the same absolute path. The raw released runtimes and verified
archive/source identities are the old/new releases recorded above.
Assembled Cosmic SHA256s:

- Old: 5503c932a6a75b5e1cfd212a3ea98a3ba35f498e95258feb21b4c7b4e151dbce.
- New: 26b019456bfd33bfa8e5624fd957353e8db7411a67a4a23836d5ff9ce1d7a313.

Both raw packages pass the exact frozen corpus from C test commit
6c32f7a07cb7272300b2e06e06ac9db85360e024: 36,895 records, byte-for-byte
cmp equality, zero mismatches; SHA256
e61139f10a9dbced988b9cd6721959a585db24d3e2d2efc18b5d60512d496048.
Both GC probes pass128 iterations retaining8 old dynamically generated
64KiB strings after input references are dropped. The exact same packages
also pass the corpus and GC probe on macOS arm64.

Candidate `env -u FUZZ_SEED -u FUZZ_ITERS COSMIC_TEST_PROFILE=linux-ci
o/bin/cosmic --make ci` passes3,549/3,549 tests, coverage318 files and
all5 stages. Then `FUZZ_SEED=34698381287 FUZZ_ITERS=50000
o/bin/cosmic --make test _fuzz/json_fuzz_test.tl` passes all3 properties
at50,000 iterations each. Saved environment stamp and individual test
results prove the deep fuzz reran after ordinary CI. A subsequent build
leaves the assembled candidate byte-identical.

Four adjacent A/B pairs through the unchanged JSON harness give long-ASCII
old/new microseconds:169.888297/23.134713,168.691660/23.234265,
169.462845/23.135095,168.828231/23.137680. All4 improve, far above noise.
The initial full53-scenario reading is retained in full-old.json/full-new.json:

| Scenario | Old median us | Old spread % | New median us | New spread % | Time delta |
|---|---:|---:|---:|---:|---:|
| json_decode_small | 1.177905 | 1.032265 | 0.913616 | 1.546460 | -22.4% |
| json_decode_large | 993.731182 | 0.897430 | 709.632298 | 2.346341 | -28.6% |
| json_encode_large | 1045.578777 | 0.563515 | 1056.993571 | 0.393851 | +1.1% |
| json_roundtrip_small | 2.613874 | 0.216898 | 2.320325 | 0.979210 | -11.2% |
| json_decode_ascii_long | 169.910126 | 1.446201 | 23.154058 | 0.318013 | -86.4% |
| json_decode_ascii_short | 28.312974 | 0.292378 | 15.437706 | 2.050668 | -45.5% |
| json_decode_ascii_escaped | 135.680412 | 0.120577 | 53.696442 | 0.677634 | -60.4% |
| json_decode_ascii_utf8 | 59.581160 | 0.267421 | 21.980255 | 1.846038 | -63.1% |

Commands use the candidate's `--make run _perf/baserun.tl --bin SUBJECT
--out FILE` with explicit PERF_BIN for each measured subject, the identical
JSON modules and separate reading files. The full candidate reading uses
`--make run _perf/run.tl --out full-new.json`. Plain compare exits1 because
http_tcp_roundtrip initially flags, not because of any JSON regression.
The mandatory final command, with PERF_BIN unset,
`--make run _perf/gate.tl compare full-old.json full-new.json
selfcheck-new.json --baseline-bin OLD_BINARY`, exits0 and prints
`perf-compare: PASS`.

The unchanged gate reruns current and baseline; disagreeing baseline
readings earn a third baseline and per-scenario median. A rekeyed HTTP
stream flag remains a regression until an additional same-new-binary
control explains the gap (about1.918ms/1.725ms/0.998ms, the last spread33.3%).
Final verdict:53 scenarios,0 regression,7 faster,46 ok,0 missing/errors.
No workload, check, threshold or gate changed. The conservative initial
JSON numbers above remain visible; the final retry still reports long
ASCII-86.4%, large JSON-32.8%, short ASCII-46.7%, with both fallback wins.
All original, retry, third-baseline, median and self-check files are retained
separately in local json-evidence/package-34698381287 and the run artifact.

The run took30m17s: about11m30s through builds/CI/deep fuzz,8m39s for a
rebuild and4 adjacent JSON pairs,5m22s for full readings/initial comparison,
and4m38s for automatic noise controls. It was making progress throughout.
Earlier run34697703704 passed all correctness but failed collecting a
.test.tmp.d directory via a file glob, before performance. Only temporary
runner collection was repaired; the complete corrected experiment reran.
Temporary validation infrastructure is not part of the product PR.

[Exact-head PR checks34697727726](https://github.com/cosmic-lua/cosmic/actions/runs/34697727726)
pass CI, build, reproducibility, macOS and Windows smoke gates. Independent
acceptance, protected landing and parent-level artifact verification are
recorded below once complete.

Independent Sol-high reviewer accepted exact7dfa1dd0 under session
d2906a8dd505af7d51c5b50cebe412da; root recorded the exact-head acceptance
and confirmed its publication, then released the reviewer lease. The
reviewer independently checked all53 unique rows with5 samples in every
full file and all8 JSON rows with5 samples in each adjacent pair, actual
archive/runtime hashes,809 ZIP entries and byte-identical payload suffix,
all correctness evidence, and the unchanged gate's HTTP noise controls.
Across4 pairs the measured time reductions were large JSON25.2–30.1%,
long ASCII86.2–86.4%, short ASCII48.8–55.2%, escaped72.9–73.3%, UTF-863.8–64.8%.
No concrete findings. Product worktree restored clean at the accepted head.

Experiment inspection after the user questioned the delay: a separate
read-only Sol diagnostic measured the focused A/B section at471.35s,
from the preceding rebuild PASS to B4 report creation. About123.1s lies
between visible make-root banners and report writes; at least75.85s is
scenario timing cadence (including the first row's minimum samples),
with about80s of harness work an estimate. The remaining approximately348s
is eight repeatable41–45s silent gaps before the make-root banners; a
42.37s gap also precedes the standalone rebuild. These gaps are outside
JSON sampling, but exact attribution within startup/orchestration is an
inference because command-entry timing was not captured.

Each arm repeats `--make run _perf/baserun.tl`; the make path prepares the
tree before baserun spawns the selected subject (_make/init.tl:183,
_make/runverb.tl:169, _perf/baserun.tl:94,159). Future runner work should
label and timestamp every phase/arm and record process wall/CPU time.
A possible optimization is preparing the scoped manifest once and using
baserun's exact argv for subsequent fresh subject processes
(`BIN --modules MANIFEST o/_perf/run.lua ...`, _perf/baserun.tl:120),
while validating roots/hashes and preserving all workloads/samples,
A/B order and separate files. This is an unimplemented future runner
suggestion, not a changed acceptance procedure for the results above.
