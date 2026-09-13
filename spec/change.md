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
