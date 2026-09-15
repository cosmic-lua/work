Switching the two files to `o/bin/gitboard`. `--make ci` here has four
stages and no build stage (run 34925846886 ends `ci: PASS (4 stages)`),
so the built binary is not guaranteed to exist when tests run; that
route needs its own decision, which this research informs.
