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
