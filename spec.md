## Evidence

gitboard has no read-only verb that lists items in a state with their
derived priority, and the two read verbs that come closest are each
narrowly capped:

- `_work/gitview.tl:108` (`TODO_SHOWN < const >: integer = 8`): bare
  `show` renders at most the front 8 of `todo` (and the front of
  `doing`), then a bare count (`... 196 more`) with no ids. No flag
  changes this — measured directly: `COLUMNS=999 gitboard show`,
  `GITBOARD_LIMIT=1000 gitboard show`, and `gitboard show < /dev/null
  | cat` (removing any tty-detection path) all still show exactly 8.
  `gitboard help show` lists only `--dir`.
- `_work/cachequery.tl:298-312` (`cmd_find`): `find TEXT...` calls
  `find.query(c, text, 20)` — a hardcoded 20-hit cap, bm25-ranked over
  titles+specs, with no state/parent/band filter at all. Measured:
  `gitboard find "the"` returns exactly 20 `«...»` lines (`| grep -c
  "^«"`) out of 997 items on the live board, and the hits mix `todo`,
  `doing`, and `ended` freely (e.g. the actual result includes `[ended]`
  rows) — there is no way to ask it for "todo items only."
- `show <root-id>` does not enumerate its own subtree either — verified
  against `i2De_o66q` (G8): the output carries `priority`, `outranks`,
  `bar`, and the spec body, nothing that lists its children.
- No verb takes a `--parent`/`--band`/`--state` filter at all; `help
  <verb>` for every read verb (`show`, `find`, `fsck`) confirms none
  accept one.

Cost observed this session: producing an accurate priority-ordered view
of the ~204-item `todo` queue for a human's prioritization pass was not
possible through any single call — the only path was `show <id>` once
per item, and even that requires already knowing every id, which
nothing enumerates.

**A second, related gap in the same area:** `gitboard spec ID FILE
--base FILE` requires the caller to supply the CURRENT spec body byte-
for-byte as `--base`, for its compare-and-swap. No verb emits just that
— `show ID` interleaves it with `role`/`priority`/`bar`/history lines,
so producing a `--base` file today means scraping `show`'s combined
output by hand (this session did it with `awk '/^--- spec ---$/{...}'`
against the `show` output, then trimmed the trailing history lines by a
second pattern match) — a fragile, easy-to-get-subtly-wrong step for
something the tool already has in hand at read time.

## The question

Two designs close the listing gap, and they trade off differently:

1. **Extend `find`** to act as the general query verb: `TEXT...`
   becomes optional, and `--state`, `--parent`, `--band` filters
   combine with it — omitting `TEXT` switches ranking from bm25 to the
   board's own derived priority order (the same one `show`/`next`
   already compute), so `gitboard find --state todo --parent
   <G3-id>` lists a filtered, priority-ordered dump, and `gitboard find
   "narrowing" --state todo` does a filtered search. One verb, one
   mental model, but it stretches "find" (a search verb) to also mean
   "list" (a browse verb), and the ranking metric silently changes
   depending on whether `TEXT` was given.
2. **Add a separate `list`/`ls` verb** carrying the filters
   (`--state`, `--parent`, `--band`, `--limit`) and leave `find` as
   pure bm25 text search, unfiltered by default but perhaps gaining the
   same `--state`/`--parent` flags for symmetry. Keeps each verb's
   contract simple, at the cost of a second read verb to document and
   keep the priority-ordering logic in `_work/priority.tl` shared
   between three call sites (`show`, `next`, `list`) instead of two.

Either design should share `show`'s existing derived-order computation
rather than re-deriving it, and should default to a sane limit
(unbounded output onto 997 items is its own usability problem) with an
explicit `--limit`/`--all` to override.

For the `spec --base` gap: the minimal fix is a flag on `show`
(`show ID --spec-only`, printing nothing but the raw spec body,
directly usable as a `--base`/`FILE` argument) — additive, no schema
change. The alternative is deeper: change `spec`'s compare-and-swap to
key off a hash/version stamp of the spec (recorded at write time)
rather than the exact prior text, which removes the byte-exactness
fragility entirely but changes the contract of every existing `--base`
caller and is a larger schema change to weigh separately from the
listing gap above.

## Non-goals

Not deciding which of the two listing designs (or the `--spec-only`
flag vs. the hash-based `--base`) is correct — both carry real
tradeoffs a refiner should weigh, not something to decide unilaterally
while filing the gap. Not a performance question: `_work/find.tl`'s
FTS5 index already answers these queries fast; the gap is purely in
what the CLI surface exposes.
