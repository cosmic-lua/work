Add `pr / compare` to the merge queue ruleset's required status checks
for cosmic-lua/cosmic's `main`. This is a repository-settings change, not
a tree change: no file in the repo carries the required-contexts list.

`.github/workflows/pr.yml`'s own `merge_group` comment records the
current set —
`grep -n "The ruleset's required contexts are the check-run" .github/workflows/pr.yml`
-> "The ruleset's required contexts are the check-run / names below
(`pr / ci|build|repro|smoke`)".

cosmic#1859 moves the reproducibility byte-compare out of `repro`, which
is a required context, and into a new `compare` job, which is not. Until
the ruleset lists it, a nondeterministic build would turn `compare` red
without blocking the queue — the gate stays green-looking and stops
gating.
