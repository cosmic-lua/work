Establish which environment the floor is recorded in (CI's `ci`
lane, by its loopback namespace and privileged identity, is the
likely answer: totals differ where sandbox and quicksand tests are
skipped locally) and make that explicit: the baseline verb refuses,
or warns and writes only the rows whose files the working tree
changed, unless `COSMIC_COVERAGE_ENV` (or an equivalent marker CI
sets) says this is the recording environment. Document the recording
environment in AGENTS.md's coverage paragraph. One PR per repo branch
that carries a `.cosmic-coverage` (main and board).
