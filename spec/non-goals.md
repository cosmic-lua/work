- **No changes under `_perf/`.** Not `gate.tl`, not `compare.tl`, not `baseline.tl`,
  not `run.tl`, not a scenario. No `--threshold` on the compare invocation and no new
  threshold constant: the bar is the one already in the tree, and inventing a
  release-specific number is the decision this slice deliberately does not make.
- **No scenario allowlist.** The gate covers every scenario the suite reports, which is
  what goals.md's "everything off the defining paths stays plain non-regression" asks
  for; do not add a defining-path filter, a per-scenario severity, or a skip list.
- **pr.yml is not touched** (its only perf mention today is the `!o/perf` artifact
  exclusion). G6's ratchet is per-release; per-PR measurement is not in this slice.
- **The size steps stay report-only** (release.yml:161-187, and `_build/size.tl:8-11`
  says so in its own words: G9 surfaces growth, never refuses it). Do not add
  `pipefail` or status propagation there, and do not touch `size.tl`.
- **The "measure the release" step (release.yml:120-127) keeps both harness runs** and
  its unguarded `set -eux`. A scenario `check()` failure already fails the release, and
  that must stay true.
- **No `continue-on-error`, no `if: always()`, no `if: failure()` publish path** on the
  compare step or the `release` job. A failed gate stops publication; that is the
  change.
- **No bypass for the same-binary refusal.** A re-dispatch on the same day and commit
  produces a byte-identical binary, whose compare `_perf/compare.tl:262-267` refuses;
  that run cannot publish anyway (the tag already exists). Leave it refusing.
- **No local-versus-release comparison anywhere** — no workflow step and no acceptance
  command that compares a locally built binary against a release asset. Baselines are
  release-runner measurements and only comparable to release-runner measurements.
- **No AGENTS.md edit** (498/500 lines) and no new decision record. The operator
  runbook is the text the failing step prints.
