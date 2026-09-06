## Evidence

Builder G3Mu_4ITj (PR cosmic-lua/cosmic#1770) changed the schema of a committed tracking file (`docs/design/cast-sites.tsv`, 3 columns → 5). The spec's `## Change` described only steady-state `--reconcile` behaviour, which cannot bootstrap a schema change: no old row carries the new key fields, so every row would orphan. The builder had to design and run an uncommitted one-off bridge script. It reported this as friction: "the brief's Change/Acceptance sections could have said explicitly that the first reconcile after this lands needs a manual bridge pass". Two other tracking-file items on the board (`.cosmic-coverage` → `--min` «DouF_FlP8», file cap → `--max-lines` «cVq7_eIpt») will meet the same fork.

The spec bar (`gitboard help bar`) has no sentence about migrating existing rows of a committed file whose shape the change alters.

## Change

Add one bar sentence to `_work/doctrine_bar.tl` (or `_work/doctrine.tl` if the bar still lives there and stays under the file cap): a `## Change` that alters the shape of a committed tracking file — a tsv, a baseline `.tl`, a `.cosmic-*` floor — states how the file's existing rows reach the new shape (a migration the change performs on first run, a one-off command the PR body names, or a rewrite committed in the same PR), and `take` refuses a spec that names such a file in `## Change` without one. Mirror in `_work/brieftext.tl`'s builder brief: one line telling the builder to commit the migrated file in the same PR and name the bridge in the PR body. Test in `_work/brieftext_test.tl` / the bar's own test file.

## Non-goals

No change to how any existing tracking file is generated. No retroactive edit of closed specs.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard help bar` prints the migration sentence; a spec fixture naming `docs/design/cast-sites.tsv` in `## Change` with no migration sentence is refused by the bar check with a message quoting the file name, and the same spec with one is accepted; the builder brief carries the line.
