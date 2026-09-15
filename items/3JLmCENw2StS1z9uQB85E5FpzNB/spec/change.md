Built and open as cosmic-lua/work#175; this item tracks it through
review and landing.

`.github/workflows/board.yml`: add an `actions/cache` step immediately
after `actions/checkout`, restoring and saving `o/`. Key is
`o-${{ runner.os }}-${{ github.workspace }}-${{ hashFiles('bin/cosmic.pin') }}-${{ github.sha }}`
with the same string minus `github.sha` as the single `restore-keys`
prefix, so `key` never hits, every run saves its own `o/`, and the
prefix finds the nearest earlier save. The workspace path is in the key
because `.cov` hit data records absolute chunk paths, so a cache
restored elsewhere would read every skipped test's coverage as 0%;
`bin/cosmic.pin` is in it because `o/` is one toolchain generation's
product and this repo resolves no other pin (`--make fetch` prints
`fetch: PASS (0 pins)`).

The gate is 396s and 94% of it is the coverage stage: run 34925846886's
log puts `lint` at 03:40:21 and `coverage` at 03:46:35, over 1352208ms
of test CPU across 161 files in 374s wall — 3.6x on 4 cores, so packing
is already near-optimal and the lever is not running the work twice.
The recipe steps are content-keyed:
`grep -n "record .* --deps" embed/cosmic.mk` in cosmic-lua/cosmic, whose
`do_record` writes `<out>.in` only on a PASS and restamps instead of
spawning when the recomputed key matches.

Measured locally with `bin/cosmic --make ci` timed by `date +%s`, where
a cold gate reproduces CI closely at 384s: every source's mtime new and
bytes unchanged -> 45s; `_work/bounce.tl` edited -> 17s, 3 files re-run;
`_work/store.tl` edited -> 31s, 5 files; nothing changed -> 4s. Every
row ended `ci: PASS (4 stages)`. The mtime row is the one that decides
it — a restored `o/` sits under a checkout where nothing has its old
timestamp, and the records re-verify bytes rather than trusting them.
