`_work/gitverbs.tl` (or a new `_work/overlap.tl` the `show`/`next`
paths both import): a function `paths_named(spec_text: string):
{string}` that extracts every backtick-quoted path-looking token
(matching an existing file under the repo root — reuse whatever path
extraction the coverage or lint tooling already does, if `_tool/`
carries one, rather than inventing a new heuristic) from an item's
`## Change` section. `gitboard show ID` gains one line, printed only
when another `todo`/`doing` item's extracted paths intersect this
item's: `overlaps: <handle> on <path>[, <path>...]` (one line per
colliding item, silent when none). `gitboard next`'s three `or: pull`
alternates gain the same annotation inline when applicable.

`_work/gitverbs_test.tl`: two fixture items whose `## Change` sections
both name `_work/brief.tl` — `show` on either prints the other's
handle under `overlaps:`; a third fixture item naming an unrelated
path prints nothing.
