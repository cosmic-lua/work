- **No gate reads the new asset**, now or as part of this change. No
  `_perf/**` file is touched at all: not `gate.tl`, not `compare.tl`,
  not `run.tl`, not `baseline.tl`. `baseline.tl` already accepts
  `--asset NAME` and needs no edit to be able to fetch it later.
- **No derived noise floor, and no bar of any kind moves.**
  `DEFAULT_THRESHOLD_PCT` stays `10.0`, `TRIAGE_K` stays `2.0`, and
  `codec_base64_roundtrip_64k` keeps its floor. Deriving a per-scenario
  floor from cross-RELEASE A/A spreads would measure runner-to-runner
  variance — the 20-33% class 3IU0GxoA recorded — and both that item's
  "What this does NOT license" paragraph and D31's rejection of a
  committed per-scenario noise profile as premature under D27 forbid
  it. This item retains evidence; it does not consume it.
- **Nothing is committed to the repo.** `o/perf/*.json` stays build
  output and stays uncommitted (AGENTS.md).
- **No second measure run, and no change to the existing two.** The
  A/A pair this publishes is the one the workflow already takes.
- **No change to `3IHHKCyz`'s diff or scope**, and no execution of it.
  That item's Direction is to drop the second measure run as redundant;
  it is recorded as blocked on this one so the deletion cannot land
  first and remove the data. Settling the tension is board work, not
  this diff's.
- No change to the `peers` job, the compare step, or the size lane.
