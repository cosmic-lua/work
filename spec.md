## Evidence

Builder session `build-zAjL_PBPK-fe8c92c8` (2026-09-06) stopped before
editing: the parent item's `## Change` anchors its new sentence
"immediately after the existing 'Between edits, `bin/cosmic --check
types <file>`' line" in AGENTS.md's Testing section. That line does
not exist anywhere in `AGENTS.md` — confirmed independently:

    $ grep -n "check types" AGENTS.md
    111:- **warnings are errors**: `--check types` fails on any Teal warning; ...

Line 111 is under "Language and Conventions", not the Testing section,
and is about warnings-as-errors, not a "check between edits" workflow
step. The Testing section (`AGENTS.md:339-384` as of this check) covers
`--make test`/`--make coverage`, the coverage floor's
environment-sensitivity, the test assertion pattern, and the fixpoint
test — it never mentions `--check types` in any form. `git log --all
-p` for the quoted phrase across all of `AGENTS.md`'s history found no
match either.

The builder's own read: the quoted "existing" line is, verbatim, the
generic builder-agent workflow boilerplate every board brief carries
(step 3 of "What to do": "Between edits, `bin/cosmic --check types
<file>` on the files you touched..."), not real `AGENTS.md` content —
this item's Evidence/Change likely conflated the two when it was
written or refined.

## Change

Re-verify where (if anywhere) `AGENTS.md`'s Testing section should
carry the parent item's actual payload — the cross-file `--check
types` staleness note (checking a file against a sibling ALSO edited
in the same session resolves `cosmic.*` requires against the last
build's embedded snapshot, not live disk, per the parent's own
Evidence) — and respec the parent (`gitboard spec 3ItZno2B <file>`)
with a real, grep-verified anchor (file:line, quoted from the tree,
not recalled) before it is pulled again. If no natural anchor exists
in the current Testing section, the respec should say where the new
sentence goes on its own (e.g., as a new bullet) rather than assuming
an "immediately after X" placement.

## Non-goals

Not re-litigating whether the underlying `--check types` staleness
finding itself is worth documenting — that finding (two builders each
losing ~20 minutes to it, per the parent's Evidence) stands; only the
anchor text is wrong.
