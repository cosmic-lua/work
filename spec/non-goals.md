No `_work/**` changes ride along — `_work/githold_test.tl` stays
self-calling in this diff; converting the board's test files to runner
mode is the follow-on item blocked on this one. If the new toolchain's
gate refuses existing machinery CODE (any stage but the
coverage-baseline numbers), that is a bounce naming what broke, not a
fix-up here. `.cosmic-coverage` is written only by `--make coverage
--baseline`, never by hand.
