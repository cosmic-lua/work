The first measurement that mattered was that packing was already near
optimal: 1352208ms of test CPU over 161 files finishing in 374s wall is
3.6x on a 4-core hosted runner, so no re-sharding or job split could
help. That ruled out the whole class of fixes the session started
looking for and left only "do not run the work twice".

Local runs, each `bin/cosmic --make ci` timed with `date +%s`, all
ending `ci: PASS (4 stages)`:

    cold, no records                           384s   161 files run
    every mtime new, bytes unchanged            45s
    _work/bounce.tl edited                      17s   3 files
    _work/store.tl edited                       31s   5 files
    nothing changed                              4s   0 files

384s local against 396s in CI is what makes the rest of these numbers
usable as predictions rather than local curiosities.

The mtime row was run specifically because it is the one that could
have falsified the change: a fresh CI checkout gives every file a new
timestamp, so an mtime-keyed cache would be worthless there. 45s says
the records re-verify bytes instead.

Caveat for whoever reviews the first CI run on work#175: it cannot show
the win. No cache exists for that key yet, so the run restores nothing
and only saves. The warm path needs a second run, and board.yml carries
workflow_dispatch, so it can be triggered without an empty commit.

Also noted while profiling, not filed as items: _work/converge_test.tl
(46.6s) and _work/gitgraph_test.tl (39.1s) spawn no git at all — their
cost is interpreted-Lua CPU from repeated in-memory index rebuilds in a
randomized walk, a different bottleneck class from the git-backed
files, and out of scope for both f6YD_gyJi's fixture work and this one.