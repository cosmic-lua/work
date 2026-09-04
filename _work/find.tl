--- Full-text search over the board: an FTS5 table layered onto an
--- already-loaded `_work.index` connection, filled from the items it
--- carries plus their spec sidecars. `build` creates and fills the
--- table in one pass, for an ephemeral connection built fresh (a
--- test, an ad hoc index); `reindex_item`/`remove_item` are the
--- single-row counterparts `_work.cache` patches its persistent
--- connection with instead. `query` is the `gitboard find` verb's
--- engine; `similar` is `new`'s pre-mint duplicate check.
--- `_work.cache` is the only production caller of any of this —
--- `find` and `new`'s duplicate check both go through its persistent
--- connection now, never a fresh `index.open` of their own.
---
--- `SIMILAR_RATIO` is measured, not guessed, against the production
--- board (914 items, loaded the way `_work.cache.rebuild` does): four
--- known duplicate/overlap title pairs — one pair with identical
--- titles, three phrased differently about the same underlying
--- binding — score their true match at a best-to-match bm25 ratio of
--- 1.00, 0.62, 0.40, and 0.27; twenty unrelated titles' own closest
--- OTHER title on the board ranges 0.21 to 0.91 (mean 0.57). The two
--- spreads overlap over their entire range — a title-only bag-of-words
--- ratio cannot tell a true duplicate from two items that are merely
--- topically related (a series of near-identical fuzz-harness titles,
--- for one) — so no threshold separates them; `SIMILAR_RATIO` is left
--- at its prior value rather than moved to a boundary the data does
--- not support.
local index = require("_work.index")
local item = require("_work.item")
local sqlite = require("cosmic.sqlite")

local type Index = index.Index

--- The search table: `id` rides along unindexed (never matched, only
--- returned), `title` and `spec` are the searched columns. `porter
--- unicode61` stems both — "refuse"/"refusing"/"refused" and
--- "duplicate"/"duplicates" collapse to the same token — so a query
--- and a title phrased in different inflections of the same words
--- still match; `unicode61` (FTS5's default) is named explicitly
--- because `tokenize` takes no default once any option is given.
local FTS_DDL < const > =
"CREATE VIRTUAL TABLE search USING fts5(id UNINDEXED, title, spec, "
.. "tokenize = 'porter unicode61')"

--- `bm25()`'s per-column weights. FTS5 binds them by COLUMN POSITION,
--- `id` (position 0) included even though it is `UNINDEXED` and never
--- scores — so a caller after `title`'s and `spec`'s weights must
--- still supply one for `id` to reach them; 1.0 is inert here since
--- `id` carries no matched terms to weight in the first place.
local BM25_WEIGHT_ID < const > = 1.0
--- A query word in the title should outrank the same word appearing a
--- handful of times in another item's spec — the title is what a
--- session scans a hit list by. At equal weight, bm25's own length
--- normalization already favors a single title hit over a lone spec
--- hit (the title is the shorter document), but a word repeated even
--- a few times in the spec overtakes it; 4.0 restores the title's lead
--- against a spec repeating the word several times over, without
--- needing an implausibly large weight.
local BM25_WEIGHT_TITLE < const > = 4.0
--- The spec's own weight — left at `bm25()`'s default so a spec-only
--- match (nothing in the title) still ranks by its ordinary relevance.
local BM25_WEIGHT_SPEC < const > = 1.0

--- Tokens a snippet shows around a match, and the marker either side
--- of an elision.
local SNIPPET_TOKENS < const > = 12
local SNIPPET_ELLIPSIS < const > = " … "

--- The top hits `similar` keeps: at most this many, before the
--- closeness filter narrows further.
local SIMILAR_LIMIT < const > = 3

--- How close a hit's rank must be to the top hit's to count as
--- "meaningfully close" for `similar`: FTS5's `bm25()` is negative,
--- more negative meaning a better match, so this is a ratio of
--- magnitudes — a hit scoring at least half as strongly as the best
--- match is kept; a title with nothing close to it returns no lines
--- rather than padding out to three with weak, unrelated matches. Left
--- at 0.5 — see the module header for why the production measurement
--- could not move it to a better-supported value.
local SIMILAR_RATIO < const > = 0.5

--- One search hit.
local record Hit
  id: string
  title: string
  state: string
  snippet: string
end

local type Rows = {Hit}

--- One raw matched row before `similar`'s closeness filter or
--- `query`'s field selection is applied.
local record Row
  id: string
  title: string
  state: string
  snippet: string
  rank: number
end

--- Quote one token for FTS5's query syntax, doubling an interior
--- quote: a bare token containing `AND`, `-`, `*`, `(`, `)`, `:`, or
--- `^` means something to FTS5's parser, but a QUOTED token is always
--- a literal string match, whatever punctuation it holds.
--- @param tok string One whitespace-free token
--- @return string The quoted token
local function escape_token(tok: string): string
  return "\"" .. tok:gsub("\"", "\"\"") .. "\""
end

--- A session's free-typed query as an FTS5 MATCH expression requiring
--- EVERY token: quoted, space-joined — FTS5 ANDs space-separated terms
--- by default, so this is "every word appears somewhere", never a
--- syntax error on a session's stray punctuation. `find`'s own
--- engine: a deliberately typed query narrows, it does not fuzz.
--- @param text string The typed query
--- @return string The MATCH expression; "" when `text` has no tokens
local function match_all(text: string): string
  local parts: {string} = {}
  for tok in (text or ""):gmatch("%S+") do
    parts[#parts + 1] = escape_token(tok)
  end
  return table.concat(parts, " ")
end

--- A candidate title as an FTS5 MATCH expression requiring ANY token:
--- quoted, OR-joined. `similar`'s engine — a near-duplicate title
--- rarely repeats every word of an existing one, so ranking needs
--- every existing item that shares AT LEAST one word, with `bm25` and
--- `SIMILAR_RATIO` doing the actual discrimination.
--- @param text string The candidate title
--- @return string The MATCH expression; "" when `text` has no tokens
local function match_any(text: string): string
  local parts: {string} = {}
  for tok in (text or ""):gmatch("%S+") do
    parts[#parts + 1] = escape_token(tok)
  end
  return table.concat(parts, " OR ")
end

--- Build and fill the search table from the index's own `items` rows
--- and `idx.specs`. Call once per index — a second call fails, the
--- table already existing.
--- @param idx Index An index from `_work.index.open`
--- @return boolean True on success
--- @return string Error message
local function build(idx: Index): boolean, string
  local ok, err = idx.db:exec_script(FTS_DDL)
  if not ok then
    return false, err
  end
  return idx.db:transaction(function(tx: sqlite.Database): boolean, string
      for row in assert(tx:query("SELECT id, title FROM items")) do
        local id = row.id as string -- cast: from any (sqlite row)
        local iok, ierr = tx:exec(
          "INSERT INTO search(id, title, spec) VALUES (?, ?, ?)",
          -- cast: from any (sqlite row)
          {id, row.title as string, idx.specs[id] or ""})
        if not iok then
          return false, ierr
        end
      end
      return true
    end)
end

--- Matched rows, ranked best first, with state and a snippet.
--- @param idx Index An index `build` has already filled
--- @param q string An FTS5 MATCH expression (`match_all`/`match_any`);
--- "" is treated as no tokens, matching nothing
--- @param limit integer Maximum rows
--- @return {Row} | nil The rows, possibly empty; nil on a query failure
--- @return string Error message
local function ranked_rows(idx: Index, q: string, limit: integer): {Row} | nil, string
  if q == "" then
    return {}
  end
  local rows, err = idx.db:query([[
      SELECT s.id AS id, s.title AS title, st.state AS state,
        snippet(search, -1, '', '', ?, ?) AS snip,
        bm25(search, ?, ?, ?) AS rank
      FROM search s JOIN state st ON st.id = s.id
      WHERE search MATCH ? ORDER BY rank LIMIT ?
    ]], {SNIPPET_ELLIPSIS, SNIPPET_TOKENS, BM25_WEIGHT_ID, BM25_WEIGHT_TITLE,
      BM25_WEIGHT_SPEC, q, limit})
  if rows == nil then
    return nil, err
  end
  local out: {Row} = {}
  for row in rows do
    local id = row.id as string -- cast: from any (sqlite row)
    local title = row.title as string -- cast: from any (sqlite row)
    local state = row.state as string -- cast: from any (sqlite row)
    local snip = row.snip as string -- cast: from any (sqlite row)
    local rank = row.rank as number -- cast: from any (sqlite row)
    out[#out + 1] = {id = id, title = title, state = state, snippet = snip,
      rank = rank}
  end
  local ierr = rows:err()
  if ierr then
    return nil, ierr
  end
  return out
end

--- Ranked hits for `text`: id, title, derived state, and a one-line
--- snippet. The `gitboard find` verb's engine.
--- @param idx Index An index `build` has already filled
--- @param text string The free-typed query
--- @param limit integer Maximum hits
--- @return Rows | nil The hits, possibly empty; nil on a query failure
--- @return string Error message
local function query(idx: Index, text: string, limit: integer): Rows | nil, string
  local rows, err = ranked_rows(idx, match_all(text), limit)
  if rows == nil then
    return nil, err
  end
  local out: Rows = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = {id = r.id, title = r.title, state = r.state,
      snippet = r.snippet}
  end
  return out
end

--- The closest existing titles to `title`, at most `SIMILAR_LIMIT`,
--- kept only when their match is meaningfully close to the best one
--- (`SIMILAR_RATIO`) — a title with nothing close returns no hits
--- rather than three weak, unrelated ones.
--- @param idx Index An index `build` has already filled
--- @param title string The candidate title
--- @return Rows | nil The close hits, possibly empty; nil on a query failure
--- @return string Error message
local function similar(idx: Index, title: string): Rows | nil, string
  local rows, err = ranked_rows(idx, match_any(title), SIMILAR_LIMIT)
  if rows == nil then
    return nil, err
  end
  if #rows == 0 then
    return {}
  end
  local best = math.abs(rows[1].rank)
  local out: Rows = {}
  if best > 0 then
    for _, r in ipairs(rows) do
      if math.abs(r.rank) >= best * SIMILAR_RATIO then
        out[#out + 1] = {id = r.id, title = r.title, state = r.state,
          snippet = r.snippet}
      end
    end
  end
  return out
end

--- Refresh one item's search row: delete then insert, so a stale
--- title or snippet never lingers after an edit — `_work.cache`'s
--- per-item counterpart to `build`'s bulk fill.
--- @param idx Index A search table `build` has already created
--- @param it item.Item The item, as freshly read
--- @param spec_body string Its spec sidecar, "" when it has none
--- @return boolean True on success
--- @return string Error message
local function reindex_item(idx: Index, it: item.Item, spec_body: string): boolean, string
  local dok, derr = idx.db:exec("DELETE FROM search WHERE id = ?", {it.id})
  if not dok then
    return false, derr
  end
  return idx.db:exec("INSERT INTO search(id, title, spec) VALUES (?, ?, ?)",
    {it.id, it.title, spec_body})
end

--- Remove one item's search row — `_work.cache`'s delete path, for an
--- id that no longer exists.
--- @param idx Index A search table `build` has already created
--- @param id string The item id
--- @return boolean True on success
--- @return string Error message
local function remove_item(idx: Index, id: string): boolean, string
  return idx.db:exec("DELETE FROM search WHERE id = ?", {id})
end

local record find
  type Hit = Hit
  type Rows = Rows
  build: function(idx: Index): boolean, string
  query: function(idx: Index, text: string, limit: integer): Rows | nil, string
  similar: function(idx: Index, title: string): Rows | nil, string
  reindex_item: function(idx: Index, it: item.Item, spec_body: string): boolean, string
  remove_item: function(idx: Index, id: string): boolean, string
end

local M: find = {
  build = build,
  query = query,
  similar = similar,
  reindex_item = reindex_item,
  remove_item = remove_item,
}

return M
