## Evidence

PR #1711 (item `nwzb_73yW`) designed a friendlier refusal for `gitboard new`
on a root item passing `--repo` with no `--parent`: "a root carries no repo:
pass `--parent ID`...". That PR landed only on `cosmic-lua/cosmic`'s `board`
branch, a stale predecessor that produces no release (see «DUkw_bCrv»). On
`cosmic-lua/work`'s `main` — the tree gitboard actually releases from —
`_work/gitgraph.tl`'s `cmd_new` still has no such early check: a root item
passing `--repo` falls through to `_work/item.tl`'s generic validation
message ("...never the board"), not the friendlier one. Confirmed 2026-09-07
by diffing both trees' `item.tl` and `gitgraph.tl` while building item
`9R8e_zA8Q` (help-text-only port of the same PR).

## Change

Port the actual `cmd_new` early-refusal check from `cosmic-lua/cosmic`'s
`board` branch (`_work/gitgraph.tl`, PR #1711) onto `cosmic-lua/work`'s
`main`: a root item (no `--parent`) passing `--repo` refuses immediately
with the friendlier message, before generic item validation runs.

## Non-goals

No change to `--repo`'s help text (already fixed by `9R8e_zA8Q`) or to
`_work/item.tl`'s generic validation message for any other case.
