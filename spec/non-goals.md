- **Do NOT change `TRIAGE_K`** (`_perf/compare.tl:27`, `2.0`) or
  `DEFAULT_THRESHOLD_PCT` (`_perf/compare.tl:19`, `10.0`). Widening
  either is the "weaken it until it passes" move this item exists to
  avoid, and it would excuse base64's real +21%.
- **Do NOT add a noise-excused scenario set**, a per-scenario
  allowlist, or any per-name special case anywhere in `_perf/`.
- **Do NOT weaken, rename, resize, or remove any scenario or its
  `check()`** — not `json_decode_large`, not
  `codec_base64_roundtrip_64k`, not any of the other six the A/A
  flagged. The `optimize` skill's standing rule.
- **Do NOT commit a per-scenario noise profile file.** The record in
  (1) rejects it explicitly; adding one here would contradict the
  record landing in the same diff.
- **Do NOT change `triage`'s existing signature**, `_perf/run.tl`, or
  any of the seven existing `compare.triage` call sites in
  `_perf/compare_test.tl`. They pin today's two-control behaviour and
  must keep passing unmodified.
- **Do NOT change `identity_refusal` or its two existing call sites'
  refusals** (`_perf/gate.tl:118`, `164`). A control whose binary does
  not match is dropped from the control set, never silently trusted.
- **Do NOT edit `.github/workflows/release.yml`.** The three
  measurements this slice consumes are already taken there; no
  workflow change is needed and none is in scope.
- **Do NOT dispatch `release.yml` with `perf_gate: false`.** It
  publishes a release outward. It is a human's call and it should wait
  on `3ISlWFiS`.
- **Do NOT touch the cosmos pin** or `bin/cosmic.pin`.
- **No `o/perf/*.json` is committed.**
