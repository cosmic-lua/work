No change to `_eval/score.tl` or `_eval/stage.tl` — `results.json`'s shape and the
run-dir layout are both already sufficient; this item only adds the journal bundler.
No change to `_perf/baseline.tl` — it is already generic via `--asset NAME` and needs
no eval-specific fork or wrapper. No `.github/workflows/release.yml` changes and no
actual eval-run invocation from repo tooling — wiring an upload/fetch step into a
release, and deciding whether tooling may invoke the agent CLI, is the next follow-up
("per-release cadence wiring"), a separate child. No comparison/ratchet gate. No
`cosmic/zip.tl` changes — `Archive:add_file` already covers this use.
