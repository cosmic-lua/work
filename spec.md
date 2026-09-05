## Evidence

A handle is the last 8 characters of the item's KSUID, rendered
`«XXXX_XXXX»`, and every id-taking verb accepts one (`_work/tail.tl`).
Resolving one loads the whole board. `_work/gitboard.tl:96-108` `resolve_id`:
`store.resolve` (a prefix glob) fails for a handle because a handle is not a
prefix, so the tail branch calls `store.list(s)` — the full load: one
`for-each-ref` plus three `cat-file --batch` passes, 125–150 ms on the live
board (the profile in «BZCt_Z5l7»'s Evidence) — and then `tail.resolve(all,
input)` matches the tail against every id. The caller (`cmd_show`, every
mutation verb) then loads the board again for its own work. That is the
3-process, ~130 ms difference the reviews of cosmic-lua/work#18 measured and
accepted as disclosed: `show <prefix>` 9 git processes, `show <handle>` 12.

The ref name IS the id, so git can match the tail itself. Measured
2026-09-05 on the live board clone (930 refs):

    $ time git for-each-ref --format='%(refname) %(objectname)' \
        'refs/heads/items/*VkzDq8u2' 'refs/heads/ended/*VkzDq8u2'
    refs/heads/items/3It5sXzLGgV9qk4l9sqVkzDq8u2 832f0ef1…
    real 0m0.007s

`for-each-ref` patterns are fnmatch, so `*<tail>` is one process and no
content read — the same shape and cost as `store.resolve`'s prefix glob
`refs/heads/items/<prefix>*`. Tails are collision-free across all 930 refs
(`… | sed 's#.*/##' | rev | cut -c1-8 | rev | sort | uniq -d | wc -l` → 0),
which `tail.tl`'s header already records. One caveat: `tail.resolve` matches
case-folded and fnmatch does not; a case-folded fallback needs only the ref
NAMES (`for-each-ref --format=%(refname)` over the two namespaces, one
process, no `cat-file`), never the content.

The cache can do it with no process at all: ids are immutable, so `SELECT id
FROM items WHERE id LIKE '%' || ? ` against `o/board.db` is exact when it
hits; a miss (an item newer than the cache) falls back to the glob.

## Change

Handle resolution costs one `for-each-ref` at most and never a load; the
whole-board load happens once per run, in the verb that needs it.

1. `_work/gitboard.tl` `resolve_id`: the tail branch stops calling
   `store.list`. It calls `refs.for_each_ref(s.root, {"refs/heads/items/*"
   .. tail, "refs/heads/ended/*" .. tail})` with the tail normalized by
   `tail.tl` (divider and guillemets stripped, both chunks), takes the
   single match, refuses on zero (the same "no item matches" message as
   today) or on more than one (the same ambiguity message), and sets the
   same one-shot `fresh_lease` ticket from the matched ref and sha that the
   prefix path sets, so the load that follows skips its own `for-each-ref`.
   `store.tl` is NOT touched (the split item «Bkbr_5S1U» is reshaping it
   concurrently); the glob call lives in `gitboard.tl` or in `tail.tl` as a
   `tail.glob_patterns(tail) -> {string}` helper.
2. Case-folding: when the exact glob matches nothing and the input has
   letters, fall back to one `refs.for_each_ref` over the two namespaces
   with names only, case-fold in Lua via `tail.resolve` against the
   returned ids, and set the ticket from that row. Still one process, no
   content.
3. Cache-first: before either glob, when `o/board.db` exists, ask
   `_work.cachequery` for `SELECT id FROM items WHERE lower(id) LIKE '%'
   || lower(?)` (one small function beside `find`); a single hit resolves
   with ZERO processes and the ticket is set from the snapshot the verb
   takes anyway (the load's own `for-each-ref`); zero hits fall through to
   step 1 (the item may be newer than the cache); two or more hits refuse
   as ambiguous. Apply the same cache-first step to `store.resolve`'s
   prefix path ONLY if it can be done without editing `store.tl` (it
   cannot today — leave it, note it for after the split).
4. Tests: `_work/gitboard_test.tl` gains a case that resolves a handle
   with `store.list` swapped for a stub that fails the test if called
   (the load must not run for resolution), one that a mixed-case handle
   resolves through the fallback with exactly one `for_each_ref` call, and
   one that a handle for an item absent from the cache still resolves
   through the glob. The existing handle-lease test keeps passing.
   Expected for the builder's own strace check (not recorded): `show
   <handle>` equals `show <prefix>` (9 on the live board today), and 8 when
   the cache answers.

## Non-goals

Editing `_work/store.tl` (split in progress); changing the handle format
or `tail.tl`'s rendering; changing any refusal string; the caller's own
whole-board load («BZCt_Z5l7» and its follow-ups).
