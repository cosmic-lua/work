## Evidence

PR #1787's review found `3p/tl/tl_patch/cast.tl`'s carried patch comment (around line 73, inside the `COSMIC_CAST_LEGALITY` gated check) still reads "the same line `_cli.lint.cast_lines` and `cast-sites.tsv` key on" — present tense, describing `docs/design/cast-sites.tsv` and its line-keyed join, both of which #1787 deleted in favor of the `_build/casts_kinds.tl` AST-pattern allowlist (`_build/cast_sites.tl`'s `cast_lines` helper is gone too). The comment explains why the diagnostic reports at the `as` token's position rather than the operand's; that reasoning still holds, but its named join target no longer exists.

## Change

Reword the comment to name the current oracle: the AST walk `_build/casts_test.tl` runs, which keys on `(path, line)` via the cast node's own position — the same node position this patch reports at. No functional change; a carried-patch comment edit only.

## Non-goals

No change to the patch's behavior or its `find`/`replace` entries' matched text (a `find`/`replace` `_patch.tl` entry's `find` string must still match the pristine tl source verbatim, so verify this edit lands in the `note`/surrounding prose the patch owns, not in text the `find` matches).

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`grep -rn "cast-sites.tsv\|cast_lines" 3p/tl/tl_patch/` prints nothing, and `bin/cosmic --make fetch && bin/cosmic --make ci` is green (confirming the patch still applies).
