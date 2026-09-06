## Evidence

`tool/lua/test_gcda_merge.lua` (the regression test for `libc/intrin/gcov.c`'s
`__gcov_write` `F_SETLKW` lock, added by cosmic-lua/cosmopolitan#380) forks
`N = 8` (line 27) children that race to rewrite the same `.gcda` file, then
asserts the merged `runs` count is exactly `baseline + N`. Three independent
fresh-context review agents, each mutating the lock away (commenting out the
`F_SETLKW` block in `__gcov_write`, `libc/intrin/gcov.c:411-418`) and
re-running the test repeatedly to confirm the guard still catches the
regression, measured a consistent, non-trivial miss rate — the mutated
(lock-removed) binary sometimes still reports the exact expected count by
chance, because `N = 8` is a small enough sample that two or more of the 8
children's read-modify-write windows sometimes don't actually collide:

- Board item `3IvOr6Gxxn8pZGF53TUjsyrD5ML` (handle `jsyr_D5ML`) PR #384,
  first review round: 3/7 runs caught the mutation under the (since-fixed)
  `-j$(nproc)` invocation — not directly comparable, since that round also
  had cross-test `.gcda` contention, but flagged the underlying test as
  probabilistic.
- Same PR, after the invocation was fixed to run serially (no external
  contention possible): the builder's own rework measured 14/23 ≈ 61% of
  serial, isolated runs caught the mutation (9/23 ≈ 39% false negatives).
- The second review round measured, in its own fresh clone, 7/8 (12.5%
  miss) on the full two-step CI sequence and 7/10 (30% miss) on the
  `test_gcda_merge.ok` target run in complete isolation (no siblings, no
  `-j` at any level) — confirming the flakiness is intrinsic to the test's
  own N=8 sample, not an artifact of anything else running concurrently.

So today, a REAL regression in the `.gcda` lock has roughly a 1-in-3 to
1-in-8 chance of passing `test_gcda_merge.ok` silently on any single CI
run — the exact kind of guard-that-can't-be-shown-to-reliably-fail this
repo's own review doctrine treats as a finding.

## Change

Increase `test_gcda_merge.lua`'s statistical power so a real lock
regression is caught reliably (target: empirically confirm a miss rate
under 5% across at least 20 mutated-lock trials, run the same way the
three measurements above were — comment out `F_SETLKW` in
`__gcov_write`, run `make MODE=cov o/cov/tool/lua/test_gcda_merge.ok`
repeatedly, restore byte-for-byte when done). Two independent levers,
either or both:

1. Raise `N` (line 27) — more concurrent writers per run means more
   chances for two children's read-modify-write windows to overlap.
   Measure the new miss rate at whatever `N` is chosen; a small bump
   (e.g. doubling) may not be enough by itself, given the 8-child
   baseline already misses roughly a third of the time.
2. Run the fork-and-race body in a loop inside the same test process
   (e.g. 3-5 iterations, each spawning its own N children and checking
   its own delta against the immediately prior reading), failing if
   ANY iteration's delta is wrong — this multiplies the chance of
   catching a regression without needing a much larger single-shot N,
   and stays closer to the test's own stated design (`baseline` then
   one exact delta) repeated rather than replaced.

Either lever must not weaken the pass criteria (still an EXACT delta
match, never a tolerance band) and must not change what a passing run
means for a genuinely-correct lock — reconfirm 10/10 clean passes with
the lock intact after whatever change is made, the same way every prior
measurement above did.

Touches only `tool/lua/test_gcda_merge.lua`. No change to
`libc/intrin/gcov.c`'s lock itself, `tool/lua/BUILD.mk`, or
`.github/workflows/pr.yml` (whose `MODE=cov` CI step, landed by
`jsyr_D5ML`/PR #384, calls this target and inherits whatever
reliability it has — no CI change needed here, the target just gets
more trustworthy underneath it). `make -j$(nproc) o//tool/lua/test`
must be green when it's done.

## Non-goals

- Not a claim that the lock itself (`F_SETLKW` in `__gcov_write`) is
  broken — every measurement above confirms it works; this item is
  about the TEST's power to detect its absence, not the lock's
  correctness.
- Not a change to `.github/workflows/pr.yml` or any other CI wiring —
  purely internal to how `test_gcda_merge.lua` measures itself.
- Not a general audit of other probabilistic tests in this repo; scoped
  to this one test, found via this one item's review cycle.
