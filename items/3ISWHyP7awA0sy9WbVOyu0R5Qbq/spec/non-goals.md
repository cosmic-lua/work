- **Do NOT re-run the A/B.** It is done and its twelve readings are in
  `## Result`. Re-running it costs two rebuilds and six measured runs
  and answers a question already answered.
- **Do NOT open a pull request**, on whilp/cosmic or on
  whilp/cosmopolitan. This slice's deliverable is evidence; PR #1417
  is what made that handover possible and is already merged.
- **Do NOT dispatch `release.yml` with `perf_gate: false`.** It
  publishes a release outward and this slice runs unattended. It is a
  human's call, and it should wait on `3ISlWFiS` — do not re-baseline
  the gate over a regression now confirmed real.
- **No scenario or `check()` is weakened, renamed, or removed** — not
  `json_decode_large`, not `codec_base64_roundtrip_64k`, not their
  input sizes. The `optimize` skill's standing rule.
- **The gate's threshold is not changed** here or anywhere without a
  decision record. Widening `--threshold`, or adding either scenario
  to the gate's noise-excused set, is the "weaken it until it passes"
  move this item exists to avoid.
- **The cosmos pin at `main` is not touched, and is not a fix.** `main`
  cannot build against the pre-bump cosmos (`## Result`), and later
  pins carry `cosmo.DecodeLua`, which `cosmic.literal` now requires. A
  real regression is fixed in whilp/cosmopolitan.
- **No `o/perf/*.json` is committed** and no `o/ab` worktree is
  re-created.
- **Do not chase the other six scenarios** the full-suite A/A flagged
  (`tar_extract_tree`, `fs_walk_tree`, `teal_check_module`,
  `literal_format_pin`, `literal_parse_pin`, `format_module_source`).
  They are this container's next question, not this slice's; if they
  still look worth a look at the end, file one capture and stop.
