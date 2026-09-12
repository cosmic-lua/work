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
