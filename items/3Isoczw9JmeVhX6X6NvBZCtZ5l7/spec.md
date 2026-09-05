## Evidence

The board now has two readers for the same facts. `_work/flow.tl` (490 lines)
and `_work/priority.tl` (478 lines) compute states, substates, roots,
blocking, and the `beats` order by walking `{Item}` in Teal; `_work/index.tl`
and `_work/index_priority.tl` express the same facts as SQL views over the
STRICT index (`open_items`, `roots`, `containers`, `workable`, `state`,
`substate`, `dominates`, `has_edge`, `own`, `ancestors`, `band`, `unplaced` —
`grep -n "CREATE VIEW" _work/index.tl _work/index_priority.tl`), held equal to
the Teal readers by differential tests (`_work/index_test.tl` 323 lines,
`_work/index_priority_test.tl` 225 lines, 19 cases between them). Only the
Teal side is read by verbs: 13 non-test modules import `_work.flow` or
`_work.priority` (`grep -rln 'require("_work.flow")\|require("_work.priority")'
_work cmd | grep -v _test`: action, flow, gitcompare, gitfsck, gitgate,
gitgraph, gitready, gitshow, gitverbs, gitverdict, gitview, health, intake),
and the views are consulted by nothing but their tests and `find`. Every save
already patches the cache (`_work/cache.tl`), so the index is current
whenever a verb runs; the duplicate reader is pure cost — two definitions of
"pullable" to keep in step, and `flow.tl`/`priority.tl` both inside 30 lines
of the 500-line cap.

Profiled 2026-09-05 (module functions wrapped with timers around
`_work.gitboard.main("show")`, live board, 929 refs): `show` 233 ms total;
`store.list` 146 ms, inside it `gitread.list` 123 ms of which the four
`cat-file --batch` reads are 102 ms inclusive — the same reads from a shell
cost roughly 40 ms, so about 60 ms of every whole-board load is Lua parsing
and item decoding, not git; then `read_specs` 19 ms, `cache.open` 15 ms,
`touched_at` 15 ms. A read served from the current cache skips all of it:
`find`, which already does, is 29 ms end to end. That is the size of this
item's prize for `show`/`next`, and why speeding the parser is not filed
separately.

## Change

Research: decide how the verbs read the index instead of `flow.tl`/
`priority.tl`, and file the file-disjoint follow-ups that do it. Deliverable
is a `--result` handover carrying the findings below plus the filed items,
not code.

1. Coverage table. For each of the 17 functions `flow.tl` exports and the 10
   `priority.tl` exports (its trailing `M = {...}` table), record the view or
   query that yields the same answer, or `none`. Prove each `same` by running
   both over the production board (`_work.cache.open` gives the connection;
   `gitread.load` the items) and diffing the result sets, pasted as counts in
   the findings. Record each `none` with the reason (an iteration order, a
   refusal string, a seeded tie-break).
2. The order wall. `priority.sorted` breaks ties with `fnv32` (priority.tl:338)
   seeded per session, and every verb's output order is frozen by its tests
   and by `gitboard-next:` lines agents read. Measure whether `cosmic.sqlite`
   can register a scalar function (`grep -n "create_function\|register"
   cosmic/sqlite/*.tl` in a cosmic checkout matched nothing on 2026-09-04;
   check the pinned `cosmo.lsqlite3` declarations in
   `o/_types/types_gen/cosmo/lsqlite3.d.tl` too). If it cannot, the decision
   is: views deliver bands and dominance, the hash tie-break stays in Teal on
   top of the view's rows. Write the decision down either way.
3. The seam. Readers move into `_work/cachequery.tl` (135 lines today) or a
   sibling `_work/cacheread.tl` when it would cross 500: one function per
   `flow`/`priority` export, same name, same return record, taking the cache
   handle instead of `{Item}`. Callers change one `require` line and one
   argument; nothing else moves. Any verb that must work with no cache (a
   fresh clone before `sync`, `fsck` on a corrupt cache) is named in the
   findings with how it degrades — rebuild first, or keep the Teal path.
4. Follow-ups. File one item per importer cluster under this same parent with
   `--repo cosmic-lua/work`, file-disjoint from each other: (a) gitshow +
   gitview, (b) gitready + intake + action, (c) gitgate + gitverdict +
   gitverbs, (d) gitgraph + gitcompare + gitfsck + health, and last (e) delete
   `flow.tl`/`priority.tl` and fold their tests into the differential tests,
   `blocked_by` (a)–(d). Each carries the coverage rows it depends on.

## Non-goals

Changing any view's definition or the STRICT schema; changing any verb's
printed output; moving the lanes observation; the embedding stage (its own
item).
