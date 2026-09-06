## Evidence

`gitboard brief builder 3IuAvpyH` («zs1K_cWnY», repo explicitly
`cosmic-lua/cosmic` — confirmed via `gitboard show zs1K_cWnY` printing
`repo: cosmic-lua/cosmic`, no missing-field warning) emitted:

    You are a builder agent for `cosmic-lua/work`, working one item from the work
    board. ...
    8. Open a PR from `3IuAvpyH` to `main` in `cosmic-lua/work`. READY

The item's own spec's `## Change` names only `cosmic-lua/cosmic` paths
(`bin/cosmic.pin`, `cosmic/searcher_test.tl`, `_build/casts_baseline.tl`,
`docs/design/cast-sites.tsv`, `docs/design/casts.md`) — nothing under
`cosmic-lua/work`'s own tree. Caught before spawning the agent by
reading the brief closely; had it gone unnoticed, the builder would
have opened its PR against the wrong repository entirely (this board's
own state repo, not the product tree the diff actually touches).

This is a THIRD occurrence of the same symptom: `KGOw_xnx8`'s friction
log (2026-09-05, `jiP8_yJF8`) recorded an identical brief wrongly
naming `cosmic-lua/work` as the PR target. But that item had NO `repo`
set at all (`ls`-confirmed no `cosmic/` tree under the board's own
checkout, `gitboard set --repo cosmic-lua/cosmic` was the fix applied)
— so that repro is consistent with `brief` merely GUESSING a fallback
when `repo` is empty, which is `HlNE_YWL2`'s scope (require `repo`/
`base` non-empty at `new --parent`/`attach` time; refuse `brief` on an
empty field instead of guessing).

This repro is different and sharper: `zs1K_cWnY`'s `repo` field is
NOT empty — it already reads `cosmic-lua/cosmic`, correctly, in
`gitboard show`'s own output — yet the brief's "Open a PR ... in
`<repo>`" line still printed the literal string `cosmic-lua/work`.
`HlNE_YWL2`'s fix (requiring the field be non-empty, refusing `brief`
when it's blank) would NOT catch this: the field here is already
correctly populated, and `brief` still ignored it. The PR-target line
in `_work/brief.tl`'s builder template appears to hardcode the string
`cosmic-lua/work` rather than substituting `it.repo`.

## Change

In `_work/brief.tl`'s builder-brief template (the function producing
the "Open a PR from `<branch>` to `<base>` in `<repo>`" line, adjacent
to `cmd_brief`'s existing `BASE_BRANCH` fill that `HlNE_YWL2` already
scopes): substitute the claimed item's own `it.repo` field into that
line instead of a literal `cosmic-lua/work`. Add a test
(`_work/brief_test.tl`) asserting that a builder brief for an item
whose `repo` is `cosmic-lua/cosmic` (or any non-`cosmic-lua/work`
value) names that repo, not the board's own, in the "Open a PR" line —
this item's own `zs1K_cWnY` repro is a ready-made fixture case.

## Non-goals

Not `HlNE_YWL2`'s scope (requiring `repo`/`base` non-empty, refusing
`brief` on an unset field) — that item's fix is necessary but not
sufficient here, since this repro's `repo` field is already correctly
set and the bug still reproduces. Not the opening line's generic "You
are a builder agent for `cosmic-lua/work`, working one item from the
work board" framing — that sentence describes the BOARD SYSTEM the
agent works within, not a PR target, and reads correctly regardless of
the item's own repo.
