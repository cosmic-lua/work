Not retroactively touching any already-attached item's stored
`repo`/`base` — existing items keep whatever they carry; this only
gates NEW `new --parent`/`attach` calls and closes `brief`'s guess for
whichever old items happen to still be missing one. Not `review`-kind
or `research`-kind briefs, or `RESEARCH_REVIEW`'s own base handling —
scope is `cmd_brief`'s `builder`-path `BASE_BRANCH` fill only, the one
site that guesses today. Not changing `gh.tl`'s `slug` fallback (origin
remote when `it.repo` is unset) — that path already only reads, never
guesses a BRANCH, and is unaffected by this item. Not a UI/help-text
change beyond the two new `attach` flags and updated refusal messages.

A second incident, 2026-09-05: six items filed with `new --parent
<G8 or its containers>` for work whose PR lands in cosmic-lua/work
(the spec sweep, the board-item `show` verdict, deleting `migrate`,
`attach` pruning, the test-suite speed item, the sqlite typed
readers) all carried no `repo`; `show` printed no target line and
nothing refused. Each was repaired afterwards with `gitboard set ID
--repo cosmic-lua/work --base main`. The decision the goal owner
asked for: `new` REQUIRES `--repo` (and takes `--base`) for every
item below the outcome level, refusing without it; an outcome carries
none and refuses one. `attach` requires them the same way when the
item has none yet. No inference from the parent: position says what
an item is, and the repo its PR lands in is a fact the filer knows.
