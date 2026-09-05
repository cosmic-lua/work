## Change

Move `--docs` search onto FTS5, replacing the substring scan and hand-rolled scoring
in `cosmic/doc/query.tl`.

Ready when: the binary the gate runs is one that carries FTS5. The tree's cosmos pin
already does; the pinned release does not yet:

```
$ bin/cosmic -e 'local db=assert(require("cosmic.sqlite").open(":memory:")); print(db:query_one("SELECT 1 AS ok FROM pragma_module_list WHERE name=?", {"fts5"}) and "present" or "absent")'
absent
$ bin/cosmic --make build && o/bin/cosmic -e '<same>'
present
```

The first command printing `present` — a `bin/cosmic.pin` bump to a release built after
cosmos `2026.09.04-65bc139fc` landed in `3p/cosmos/cosmos_pin.tl` (PR #1705) — is the
ready signal. Under the converged `--make ci` the second binary is what runs, so the
change itself gates today; the pin bump is what lets a cold generation-1 build of a
tree that requires FTS5 pass too.

Search today is `string.find` plus a scoring function:

```teal
local query_lower = query:lower()
local module_contains_query = mod_name:lower():find(query_lower, 1, true) ~= nil
calc_score(simple_lower, mod_doc.module_doc, query_lower, 100, 80, 30)
```

so it matches literal substrings only, in one case-folded pass over every module,
function and record in the embedded index. There is no tokenisation, no stemming, no
phrase or prefix query, no ranking beyond the hand-tuned weights above, and a query of
two words matches nothing unless those exact bytes appear adjacently:

```
$ o/bin/cosmic --docs "json decode"
error: documentation not found for 'json decode'
Use 'cosmic --docs' to see available modules.
$ o/bin/cosmic --docs "walk directory"
error: documentation not found for 'walk directory'
```

With FTS5 in the library, this becomes an index build plus a `MATCH` query with
`bm25()` ranking — a real retrieval function that already knows how to weight columns,
so `calc_score`'s magic numbers (100, 80, 30 / 95, 75, 25) become `bm25()` column
weights that mean something.

### Decisions, measured (2026-09-05, tree c39fc2f, o/bin/cosmic built from it)

**Where the index lives: built in memory, on the search path only.** The doc index
ships as `.docs/index.lua` (2,033,153 bytes; `cmd/cosmic/embed_gen.tl`'s
`write_index`). Building an FTS5 table from it at query time costs less than the whole
command costs today:

```
in-memory FTS5 over the embedded doc index: 5954 rows in 41 ms   (one row per module,
                                                                  function, record,
                                                                  record method, example)
$ for q in fs "walk directory" "json decode"; do s=$(date +%s%N); o/bin/cosmic --docs "$q" >/dev/null 2>&1; e=$(date +%s%N); echo "$(( (e-s)/1000000 )) ms  --docs '$q'"; done
47 ms  --docs 'fs'
48 ms  --docs 'walk directory'
62 ms  --docs 'json decode'
```

The exact-lookup path (`--docs fs`, `--docs cosmic.fs.walk`) never searches, so it pays
nothing; only the fallback in `_cli/main_handlers.tl`'s `handle_docs` (exact lookup
failed, `docs.search(query)`) builds the table, once per process. Shipping the same
rows as a SQLite file was measured and rejected for now: the file is 2,043,904 bytes
raw (509 KB gzipped inside the zip, the same as `index.lua`), it would sit BESIDE
`index.lua` because exact lookup still reads the Lua table, and `lsqlite3`'s
`deserialize` is unwrapped in `cosmic.sqlite` (`grep -n deserialize cosmic/sqlite/*.tl`
→ nothing). Revisit only if the `_perf` scenario below shows the 41 ms mattering.

**Ranking keeps an exact-name boost on top of `bm25()`.** Measured with the prototype
above, weights `bm25(d, 1, 1, 4.0, 1.0)` over `(module UNINDEXED, kind UNINDEXED, name,
description)`, tokenizer `porter unicode61`, every query token required:

```
  walk directory       -> cosmic.fs.find FileIter.close(method) | cosmic.fs.walk (module) | cosmic.embed write(function)
  json decode error    -> cosmic.json Example_decode_error(example) | cosmic.fetch Response.json(method) | cosmic.json decode_object(function)
  sha256               -> cosmic.hash HashModule.sha256(method) | cosmic.hash sha256_hex(method) | cosmic.hash sha256(function)
  read file lines      -> cosmic.literal format(function) | cosmic.literal (module) | cosmic.format.types is_function_block_opener(function)
```

Two-word queries land; single common words (`read`, `lines`) rank by description
frequency, which is worse than today's name-first substring boost for a query that IS a
symbol name. So: an exact or prefix match on the simple name or the dotted name keeps
its rank ahead of every bm25 hit (the boost is a fixed offset added before sort, not a
bm25 weight), and bm25 orders the rest. Porter stemming stays: `refuse`/`refusing`
collapse, which the substring scan never did.

**Behaviour when FTS5 is absent: the substring path stays, chosen at runtime.** Ask
`pragma_module_list` exactly as `cosmic/sqlite/zipfile_test.tl` does; a build without
FTS5 searches as it does today. The test for the new path skips aloud (exit 2, the
`skip` status `_tool/records.tl` defines) when the module is absent, never passes
vacuously.

**MATCH escaping comes from «J9eH_ond1»** (`escape_token`/`match_all` in
`cosmic.sqlite`), which this item is blocked on: a free-typed query holding `-`, `*`,
`:` or `AND` must read as words, and the builders are that contract in one place.

### Files

- `cosmic/doc/search.tl` (new; `query.tl` is at 483 lines of a 500 cap, so the engine
  cannot go there): `build(index: DocIndex): Database | nil, string` (the in-memory
  table), `search(index, query, include_cosmo): {SearchResult}` returning the same
  `SearchResult` shape `cosmic/doc/types.tl` declares so `render_search_results` in
  `show.tl` is untouched; `is_available(): boolean` (the pragma probe).
- `cosmic/doc/query.tl`: `search` dispatches to `search.tl` when available and to the
  existing scan otherwise; `calc_score` and `lookup.tl` stay for the fallback.
- `cosmic/doc/search_test.tl`: a multi-word query that fails today (`json decode`)
  returns `cosmic.json`'s decode entries first; the exact-name boost holds
  (`--docs walk` still puts `cosmic.fs.walk` first; today's output for the record is
  below); a query with FTS5 syntax characters (`fs.read -x`) returns rows rather than a
  syntax error.
- `_perf/bench/docs_bench.tl` (new scenario module, the `_perf/bench/*_bench.tl`
  shape): `--docs "json decode"` end to end, so the 41 ms is a reading the daily
  compare holds, and the shipped-file alternative has a number to beat.

Representative queries to capture BEFORE the change and paste in the PR, so ranking
regressions are visible: `fs`, `walk`, `json`, `decode`, `slurp`, `sqlite query`,
`child run`, `sha256`, `fetch json`, `busy_timeout`. Today's `walk`:

```
$ o/bin/cosmic --docs walk
Search results for 'walk':
  cosmic.fs.walk (module)  (internal)
  _cli.nilreturn.walk (function)  (internal)
  _cli.nilreturn.Walk (record)  (internal)
  _cli.nilreturn.NilReturnModule.walk (method)  (internal)
```

## Non-goals

- No change to what the doc index contains or to `_tool/doc`'s extraction half
  (identifier-fragment matching over names and example bodies is its own item).
- No change to `--docs`'s output format.
- No vector or semantic search.
- Not shipping a SQLite file in the artifact — measured above, revisit from the perf
  reading.
