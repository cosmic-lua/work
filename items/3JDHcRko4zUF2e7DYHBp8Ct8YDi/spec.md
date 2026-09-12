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
