A derived `events` table in the cache, one row per commit on an item's
ref, rebuilt from one log walk and patched on every save.

1. `_work/cachedb.tl` schema, STRICT, WITHOUT ROWID:
   `events(item TEXT NOT NULL REFERENCES items(id), seq INTEGER NOT NULL,
   sha TEXT NOT NULL, at INTEGER NOT NULL, verb TEXT NOT NULL, session TEXT
   NOT NULL DEFAULT '', pr INTEGER NOT NULL DEFAULT 0, subject TEXT NOT
   NULL, PRIMARY KEY(item, seq))`, with `CREATE INDEX events_pr ON
   events(pr) WHERE pr <> 0` and `CREATE INDEX events_verb ON
   events(verb)`. `seq` is the commit's position from the root (1 = the
   `new`), so `ORDER BY seq` is history oldest-first. The schema
   fingerprint (cosmic-lua/work#14) makes this a rebuild; no hand version.
2. `_work/events.tl` (new): `parse_subject(s) -> {verb, session, pr}` —
   verb is the first token; session the token after ` by `; pr the integer
   after `pr:`; anything unparsed leaves the default, never a refusal —
   and `walk(root, refs) -> {Row}` running the one `git log
   --format='%H%x00%ct%x00%s' <refs>` with `--source`-free attribution:
   walk per ref is O(refs) processes, so instead use one `git log` with
   `--format='%H %ct %P %s'` plus the ref tips from the snapshot and
   assign each commit to its item by following first-parent chains from
   each tip (items never share commits: every ref is its own root
   history, `_work/gitwrite.tl`). Record the choice and its cost in the
   header.
3. `_work/cache.tl`: `rebuild` fills `events` from `walk`; the save patch
   (`_work/gitwrite.tl` returns the new commit's sha and the request
   carries its message) appends one row per written ref with
   `seq = previous max + 1`; the fetch patch, for each ref whose sha
   moved, walks `old..new` for that ref only.
4. Readers: `_work/publish.tl` `history(s, id)` returns rows from `events`
   when the cache is current, falling back to the `git log` process only
   when it is not; output of `show ID`'s history block is byte-identical
   (assert in `_work/gitshow_test.tl` by rendering both ways).
5. Views, in `cachedb.tl`: `pr_rounds(item, pr, taken_at, verdicts,
   accepted_at)` — one row per (item, pr) with the first `take … pr:N`
   time, the count of `verdict` rows, and the accept time — enough to
   answer the three questions in Evidence with one SELECT each; put the
   three SELECTs in `_work/events_test.tl` against a fixture board so the
   views are held by tests, the way `_work/index_test.tl` holds the state
   views.
6. Tests: `parse_subject` over every distinct subject shape in Evidence
   (current and legacy); rebuild equals the per-item `git log` for a
   fixture with three items and a rework round; save patch keeps `seq`
   contiguous; fetch patch after an external commit lands the new rows.
7. Line caps, measured at head c78bedbb (2026-09-05): `_work/cache.tl`
   is 475 lines and `_work/cachedb.tl` 438, so steps 1 and 3 do not fit
   in place. The cache-side event logic (the rebuild fill, the save
   patch, the fetch patch) lives in `_work/events.tl` beside `walk` and
   `parse_subject` (or a second new module `_work/cacheevents.tl` if
   `events.tl` would pass 500), and `cache.tl` gains only the calls into
   it. The DDL and the `pr_rounds` view go in `cachedb.tl` if they fit
   under the cap; otherwise in a new `_work/cachedb_events.tl` that
   `cachedb.tl`'s schema list includes, so the fingerprint still covers
   it. Moving unrelated code out of either file is not this item.
