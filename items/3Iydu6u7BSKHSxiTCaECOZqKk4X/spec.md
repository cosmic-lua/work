## Evidence

cosmic#1778 replaced the `.cosmic-coverage` ratchet with `--make coverage --min PCT [--min-file PCT]` and first stated the tree's floor on `.github/workflows/pr.yml`'s `bin/cosmic --make ci` line as `--min 76 --min-file 0`. CI's `ci` lane failed in 20 ms: `make: unknown flag '--min' for ci` — the lane's first `--make ci` runs under the PINNED release (`bin/cosmic.pin`, 2026-09-06-b5a9003), whose embedded make engine parses the verb's flags before anything builds, so a flag the pin has never seen is refused in generation 1 regardless of what the tree's `_make/flags.tl` accepts (run 34069880430, job 101585135075). The flags were removed from pr.yml with a comment naming this item; until they are back, the tree's coverage has NO enforced floor (the spec's "neither option → report and pass").

## Change

After a cosmic release carrying #1778 exists and `bin/cosmic.pin` is bumped to it (that bump is its own item, the usual hand-build), `.github/workflows/pr.yml`'s `ci` lane invocation becomes `bin/cosmic --make ci --min 76 --min-file 0` (the numbers measured at #1778: 76.48% overall, lowest row 0%), and the staging comment above it is removed. One line plus the comment; nothing else.

## Non-goals

No change to the numbers' meaning; no per-project override; no change to `_make/flags.tl`.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`bin/cosmic.pin` names a release whose `bin/cosmic --make ci --min 0` is accepted (`--make help` lists `--min`), and pr.yml's `ci` line carries `--min 76 --min-file 0` with CI green on it.
