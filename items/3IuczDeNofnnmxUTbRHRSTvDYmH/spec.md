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

**A second, related gap: `show`/`find` are prose-only, so every
narrower need this session had was met by piping their output through
an external text tool instead of gitboard itself** — every instance,
this session, verbatim:

    gitboard show 2>&1 | grep "^todo"
    gitboard show $id 2>&1 | grep -E "^(parent|priority|state|bar):"     # run ~15 times,
                                                                          # once per item inspected
    gitboard show $id 2>&1 | sed -n '/--- spec ---/,/^  20/p' | head -25 # extracting just a spec body
    awk '/^--- spec ---$/{flag=1; next} /^  [0-9]{4}-[0-9]{2}-[0-9]{2}T/{flag=0} flag'  # same, precise
    gitboard find "the" 2>&1 | grep -c "^«"                              # counting hits

Every one of these is a workaround for the same missing capability:
`show`/`find` emit one fixed, human-formatted report with no way to
select a section or a field. `gitboard spec ID FILE --base FILE`
concretely depends on this gap: `--base` needs the CURRENT spec body
byte-for-byte, and the only way to get it today is the `awk` line
above, scraping `show`'s combined header/bar/spec/history output by
hand — fragile, and easy to get subtly wrong (the history section's
own lines can collide with a naive delimiter pattern).

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

For the section/field-scraping gap, two shapes, not mutually
exclusive:

- **`show ID --section <fields|bar|spec|history>`**: prints exactly
  that section as raw text, nothing else — directly usable as
  `--base`/`FILE` for `spec`, or piped through `grep` for one field
  without the surrounding report contaminating matches. Additive, no
  schema change, and it would have replaced every `grep -E
  "^(parent|priority|state|bar):"` and the `sed`-extracted spec body
  above outright.
- **`--json` (or a per-call `--field NAME`) on `show`**: structured,
  machine-parseable output — the deeper fix for scripts (this session
  included) that want a specific field (`priority`, `state`, `parent`)
  without parsing prose at all, at the cost of a stable schema to
  define and keep across the CLI (`show`, `find`, a future `list`
  would all want to agree on one shape).

`spec`'s compare-and-swap has a third, independent option worth naming:
key `--base` off a hash/version stamp of the spec (recorded at write
time) rather than exact prior text, removing the byte-exactness
fragility entirely — a larger schema change to weigh separately from
the display-format questions above, since it changes what every
existing `--base` caller passes.

## Non-goals

Not deciding which listing design, which section/output-format shape,
or the hash-based `--base` is correct — each carries real tradeoffs a
refiner should weigh, not something to decide unilaterally while filing
the gap. Not a performance question: `_work/find.tl`'s FTS5 index
already answers these queries fast; the gap is purely in what the CLI
surface exposes.
