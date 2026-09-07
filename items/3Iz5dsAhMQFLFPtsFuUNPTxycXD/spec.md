## Evidence

PR #1787's review found `3p/tl/tl_patch/cast.tl`'s carried patch comment (around line 73, inside the `COSMIC_CAST_LEGALITY` gated check) still reads "the same line `_cli.lint.cast_lines` and `cast-sites.tsv` key on" — present tense, describing `docs/design/cast-sites.tsv` and its line-keyed join, both of which #1787 deleted in favor of the `_build/casts_kinds.tl` AST-pattern allowlist (`_build/cast_sites.tl`'s `cast_lines` helper is gone too). The comment explains why the diagnostic reports at the `as` token's position rather than the operand's; that reasoning still holds, but its named join target no longer exists.

**Revision note.** The original version of this spec's fix named the
NEW current oracle (`_build/casts_test.tl`) in place of the old one —
which `«MsXN_oznh»` (landed or landing around the same time) deletes,
making that reworded comment stale again the moment it lands, the same
failure mode one generation later. Per `docs-style`
(`skills/docs-style/SKILL.md`): a code cross-reference is fine when it
points the reader at code to go look at next, but a reference used AS
THE JUSTIFICATION for why a line of code is shaped the way it is
should state the rationale itself, not point at whichever file
currently plays that role — that pointer is exactly what went stale
here the first time. This revision inlines the invariant instead of
naming a joinable file at all, so nothing here needs updating again
when the classifier's own file moves or is deleted a second time.

## Change

Reword the comment to state the INVARIANT directly instead of naming a
file: node's own `y`/`x` is the `as` token's position (set at parse
time, `tl.lua`'s `parse_expression`) — reporting here instead of at
`node.e1` (the operand) keeps this diagnostic's position consistent
with how a cast site is identified everywhere else in the tree: by its
exact `(file, line)`. Reporting at the operand instead would let this
diagnostic's line drift from whatever else keys a cast by position,
silently breaking any future join without this patch changing at all.
No functional change; a carried-patch comment edit only. No file name
(`_build/casts_test.tl`, `_cli/lint.tl`, or otherwise) appears in the
reworded comment — the invariant holds regardless of which module
currently keys casts by position.

## Non-goals

No change to the patch's behavior or its `find`/`replace` entries' matched text (a `find`/`replace` `_patch.tl` entry's `find` string must still match the pristine tl source verbatim, so verify this edit lands in the `note`/surrounding prose the patch owns, not in text the `find` matches).

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`grep -rn "cast-sites.tsv\|cast_lines\|casts_test.tl" 3p/tl/tl_patch/` prints nothing, and `bin/cosmic --make fetch && bin/cosmic --make ci` is green (confirming the patch still applies).
