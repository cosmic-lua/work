## Evidence

PR #1746 (board item `LVYj_DA0K`)'s `ci` check fails at head `10cb2ffe`
with a cold-build (generation 1) type error:

    cosmic/errno.tl:52:15: error: invalid key 'E' in record 'unix' of type unix
    cosmic/errno.tl:97:39: error: invalid key 'E' in record 'unix' of type unix
    make: the converging build failed; this build ran under the tree's
    own o/bin/cosmic, which may not match this tree — `rm o/bin/cosmic`
    and re-run to rebuild from the pin

Re-ran the failed job once (`rerun_failed_jobs` on run `34036882731`):
identical failure, same two lines, ~20s runtime (consistent with a
build that starts from a populated `o/`, not a genuinely cold one) —
rules out a one-off transient flake.

Independently reproduced a GENUINELY cold build of the exact same head
(`10cb2ffe`) locally: fresh worktree, `rm -rf o`, `bin/cosmic --make
fetch` (network, real pins), `bin/cosmic --make ci` — result:
`ci: PASS (5 stages)`, 289 checks / 3342 tests, no error at
`errno.tl:52` or anywhere else. `unix.E` resolves correctly as a real
field there.

So the same head commit, cold-built twice, disagrees: local succeeds,
CI's `ci` job fails identically on two separate runs. The gate's own
error message self-diagnoses a stale `o/bin/cosmic` — CI's
`actions/cache` step (`.github/workflows/pr.yml:134-143`) keys on
`hashFiles('bin/cosmic.pin')` plus `github.sha`, which on paper should
force a cache miss whenever the pin changes (as it did here, via the
merge-in of #1748's pin bump) — but the observed behavior says
something is still serving a pre-bump `o/bin/cosmic` into the job.
Not yet root-caused past this point: either the cache key isn't
missing the way its own construction implies, or there's a genuine
environment difference between CI's sandboxed non-root run and a local
root-shell run that affects `_types/gentype_parse.tl`'s generation
step specifically (this repo's own `cosmic/coverage/SENSITIVITY.md`
already documents root-vs-non-root and Landlock moving OTHER measured
rows; whether generation is also sensitive is unconfirmed).

## Impact

Blocks PR #1746 (and will block any PR whose diff needs a just-bumped
`bin/cosmic.pin` to pass gen1) with a false-negative red `ci` check —
the diff itself is correct, proven by the clean local cold build on
the identical commit. Review doctrine (`help review`) correctly
refuses to accept a PR with red CI regardless of an out-of-band local
repro, so this needs an actual fix (or a proven cache-bust), not a
review override.

## Non-goals

Not a code defect in `LVYj_DA0K`/PR #1746's actual diff — that diff is
confirmed correct against a genuinely cold local build. Not
`RNb7_b0tV`'s gentype_parse.tl fix itself, which also checks out
locally. Scope here is CI's own build environment / cache behavior
around a pin bump.
