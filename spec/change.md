Blocked on «J9eH_ond1» (the MATCH builders it lands are reused, never duplicated).

1. `cosmic/sqlite/fts.tl` (new shard, requireable as `cosmic.sqlite.fts` — public by
   position is `cosmic.sqlite`; the shard is reached through the parent record the way
   `cosmic.sqlite.bind`'s types are: `sqlite.fts.<fn>`). Surface, every function
   `value | nil, string`:
   - `is_available(db: Database): boolean` — the `pragma_module_list` probe
     `cosmic/sqlite/zipfile_test.tl` runs, so a caller on a build without FTS5 can
     choose its fallback instead of failing on `CREATE VIRTUAL TABLE`.
   - `create(db, name: string, spec: TableSpec): boolean, string` where `TableSpec`
     is `{columns: {string}, unindexed?: {string}, tokenizer?: Tokenizer, content?:
     string, content_rowid?: string}` and `Tokenizer` is an enum of the four this
     build carries (`"unicode61"`, `"porter unicode61"`, `"trigram"`, `"ascii"`) plus
     the `tokenchars` option as a field, so the DDL string is built once, correctly
     quoted, and a misspelled tokenizer fails at the Teal checker.
   - `add(db, name, row: {string: any}): boolean, string` and `remove(db, name, rowid:
     integer)` — thin, so an external-content table's sync is two calls.
   - `search(db, name, query: string, opts?: SearchOptions): {Hit} | nil, string`
     where `SearchOptions` is `{weights?: {string: number}, limit?: integer, snippet?:
     string, snippet_tokens?: integer, match?: "all" | "any"}` and `Hit` carries every
     column plus `rank: number` (bm25, negative-is-better as FTS5 defines it) and
     `snippet: string | nil`. `weights` is keyed by COLUMN NAME and turned into the
     positional `bm25(t, w0, w1, ...)` list from the table's declared column order
     (read back from `pragma_table_info`), so the position trap is closed in one
     place; `query` goes through «J9eH_ond1»'s `match_all`/`match_any`; `snippet`
     names the column, with `SNIPPET` markers `[`/`]` and ` … ` defaulted and
     overridable.
   - `optimize(db, name)` — `INSERT INTO t(t) VALUES('optimize')`, for a table built
     once and read many times (the `--docs` index).
2. `cosmic/sqlite/fts_test.tl`: skips aloud (exit 2) when `is_available` is false;
   creates a `porter unicode61` table, adds three rows, and asserts a two-word query
   ranks the row holding both first with its snippet; `weights` by name reorders a tie
   the way the positional list would; a query holding `-x AND (y` returns rows, not a
   syntax error; a `trigram` table matches a four-character fragment; `create` with
   an unknown tokenizer is a Teal error (a `-- assert:`-free negative test through the
   enum's checker, in `cosmic/sqlite/fts_test.tl`'s fixture compile).
3. `cosmic/sqlite/init_example.tl` gains `Example_full_text_search`: five rows, one
   query, printed hits with snippets — the "two statements" promise shown, and the
   example gate runs it.
4. `cosmic/sqlite/init.tl`'s header gets the one sentence naming the shard; `--docs
   cosmic.sqlite` renders it.
5. `_work/find.tl` is NOT changed here (a different repository); its shrink onto the
   battery is a follow-up on the work board once this lands.
