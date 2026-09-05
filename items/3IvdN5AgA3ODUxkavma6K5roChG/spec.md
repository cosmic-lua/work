## Change

Agents iterate on this repository and on gitboard's by running the
whole `bin/cosmic --make ci` after every edit — 2 to 4 minutes a turn,
six to ten turns a slice across sixteen slices measured today —
because AGENTS.md documents `--make test <path>` as the only narrowing
and never says that a type error, a lint failure, and a coverage row
each come back on a separate full run. Add one paragraph to AGENTS.md
under Testing, titled the inner loop: type-check the files you
touched first (`bin/cosmic --check types <files>`, under a second),
run the one test file (`--make test <file>`), run `--make lint`
(seconds) before any full gate, and run `--make ci` once at the end;
state the measured cost of each on this repository. Say that a
declined or missing `.cosmic-coverage` row is reported by the coverage
stage with the row to paste, so a new file costs one gate, not two.
Mirror the paragraph in cosmic-lua/work's README, whose gate is the
same tool.
