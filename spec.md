## Evidence

An agent working from the binary alone searches for what it remembers: a fragment of
an identifier (`busy_time`), an option name it saw in an error, a call it wants an
example of (`json.decode`). `--docs` search matches names by substring today and, after
the FTS5 move («So6c_e5pY»), by stemmed WORDS — and `porter unicode61` turns
`busy_timeout` into `busi` and `timeout`, `sha256_hex` into `sha256` and `hex`
(measured through an `fts5vocab` table: `busi hex sha256 timeout`), so an
identifier fragment stops matching once words are the unit. Both engines miss what
the index already holds:

```
$ o/bin/cosmic --docs busy_timeout
Search results for 'busy_timeout':
  cosmic.sqlite.defaults.apply (function)  (internal)
    Apply cosmic's per-connection defaults to a freshly opened handle:
```

`busy_timeout` is a public `Options` field of `cosmic.sqlite` (its init.tl header:
"a 5000ms busy timeout ... each has an `Options` field"), and the one hit is an
internal shard, because record FIELDS that are not functions are not search entries
(`cosmic/doc/query.tl`'s `search` scores `fields` only when `ftype:match("^function")`)
and example BODIES are never searched (`ExampleDoc.body` is rendered by `--examples`,
never matched).

SQLite 3.53.3 ships the `trigram` tokenizer, and this build accepts it:

```
$ o/bin/cosmic -e 'local db=assert(require("cosmic.sqlite").open(":memory:")); print(db:exec("CREATE VIRTUAL TABLE t USING fts5(x, tokenize=\"trigram\")"))'
true
```

A trigram column matches any substring of three or more characters, case-folded,
and also accelerates `LIKE '%frag%'` on that column — so one column typed `trigram`
gives identifier-fragment search over names, signatures, field names and example
bodies without stemming them. Measured on the whole 4.6 MB of `.tl` source as a bound:
720 ms to build, 16 MB in memory, `MATCH 'busy_timeout'` in under 1 ms. The doc
index's identifier text (names, signatures, field names, example bodies) is a small
fraction of that.

## Change

Blocked on «So6c_e5pY» — this adds a column to the table that item creates.

1. `cosmic/doc/search.tl`: the in-memory table gains a second FTS5 table (one FTS5
   table has one tokenizer), `ident(module UNINDEXED, kind UNINDEXED, name, text,
   tokenize='trigram')`, filled with: every function's `name` and `signature`; every
   record's name and each field's name and type text (function fields and plain
   fields alike, so `busy_timeout: integer` is a row); every example's name and
   `body`. `search()` runs the word query and the trigram query, merges by
   `(module, symbol)`, and ranks: exact-name boost first (unchanged), then rows
   matched in BOTH tables, then bm25 order within each. A query under three
   characters skips the trigram table (it cannot match).
2. New `SearchResult.symbol_type` values `field` (a non-function record field, rendered
   as `cosmic.sqlite.Options.busy_timeout (field)  integer`) and `example-body` (an
   example whose body matched, rendered with the example's name and the matched line
   via `snippet()`), added to `cosmic/doc/types.tl` and rendered by
   `show.tl`'s `render_search_results` — two new cases in one `if` chain.
3. Measured queries to hold in `cosmic/doc/search_test.tl`: `busy_timeout` →
   `cosmic.sqlite.Options.busy_timeout (field)` first; `json.decode` → an example whose
   body calls it, listed with the line; `sha256_hex` → `cosmic.hash.sha256_hex` first
   (both tables match; the exact-name boost holds); a two-character query returns the
   word-table results only.
4. `_perf/bench/docs_bench.tl` (from the parent item) gets the trigram build in its
   scenario — the second table roughly doubles the build, and the number is the
   reading that says whether it is worth keeping in memory or shipping.

## Non-goals

Searching the artifact's compiled `.lua` modules (comments are gone after generation;
the doc index is the text). Tree-side source search over `.tl` files — a `_tool/`
report for sessions with a checkout, not an agent with a binary; file it separately if
the eval transcripts show the need. Fuzzy (edit-distance) matching: `cosmic.fuzzy`
already backs the not-found suggestion, and trigrams cover the fragment case.
