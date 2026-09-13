No release.yml change: wiring `--baseline-bin` into the release
compare step is its own follow-up once the flag proves out locally
(file it at review if this lands). No change to `triage_many`,
`TRIAGE_K`, or the noise-bar formula of the existing stages. No new
module unless the test cap forces the test split named above. Frozen:
the `perf-compare: PASS|FAIL` verdict line format, and the results
JSON shape (the A/B stage reads standard `run.tl` outputs).
