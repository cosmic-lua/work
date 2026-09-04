--- Full-text search over the board: an FTS5 table layered onto an
--- already-loaded `_work.index` connection, filled from the items it
--- carries plus their spec sidecars — read once, batched
--- (`store.read_specs`), and handed to `index.open` rather than
--- re-read here. `build` creates and fills the table; `query` is the
--- `gitboard find` verb's engine; `similar` is `new`'s pre-mint
--- duplicate check.
local index = require("_work.index")
local sqlite = require("cosmic.sqlite")
local store = require("_work.store")
local tail = require("_work.tail")

local type Index = index.Index

--- The search table: `id` rides along unindexed (never matched, only
--- returned), `title` and `spec` are the searched columns.
local FTS_DDL < const > = "CREATE VIRTUAL TABLE search USING fts5(id UNINDEXED, title, spec)"

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
--- rather than padding out to three with weak, unrelated matches.
--- Chosen by inspection of real title-collision pairs during
--- development, not tuned against a labeled set; a later pass with
--- real false-positive/negative counts may want to move it.
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
        bm25(search) AS rank
      FROM search s JOIN state st ON st.id = s.id
      WHERE search MATCH ? ORDER BY rank LIMIT ?
    ]], {SNIPPET_ELLIPSIS, SNIPPET_TOKENS, q, limit})
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

--- `similar`'s hits as `new`'s pre-mint warning lines — the whole
--- read-specs/open-index/query/close cycle in one call, so wiring it
--- into a verb costs one `for` loop. Infallible by design: this is a
--- warning, never a refusal, so a failure anywhere in the cycle (an
--- empty board, a transient index-build problem) is not the caller's
--- to handle — it simply means no lines to print, the same as a title
--- with nothing similar on the board.
--- @param s store.Store The store
--- @param title string The candidate title
--- @return {string} "similar: «handle» title" lines, at most three,
--- possibly none
local function similar_lines(s: store.Store, title: string): {string}
  local all = store.list(s)
  if all == nil then
    return {}
  end
  local ids: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
  end
  local idx = index.open(all, store.read_specs(s, ids))
  if idx == nil then
    return {}
  end
  if not build(idx) then
    local _ok, _cerr = index.close(idx)
    return {}
  end
  local hits = similar(idx, title)
  local _ok2, _cerr2 = index.close(idx)
  local out: {string} = {}
  for _, h in ipairs(hits or {}) do
    out[#out + 1] = ("similar: %s %s"):format(tail.handle(h.id), h.title)
  end
  return out
end

--- `find TEXT...`: every hit for the joined query, ranked, one line
--- each — handle, state, title, snippet — then the verdict line
--- `gitboard-find: N hit(s)`.
--- @param s store.Store The store
--- @param text string The query text
--- @return integer Exit code
local function cmd_find(s: store.Store, text: string): integer
  local all, aerr = store.list(s)
  if all == nil then
    print(("gitboard-find: %s"):format(aerr))
    return 1
  end
  local ids: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
  end
  local idx, ierr = index.open(all, store.read_specs(s, ids))
  if idx == nil then
    print(("gitboard-find: %s"):format(ierr))
    return 1
  end
  local bok, berr = build(idx)
  if not bok then
    local _ok3, _cerr3 = index.close(idx)
    print(("gitboard-find: %s"):format(berr))
    return 1
  end
  local hits, qerr = query(idx, text, 20)
  local _ok4, _cerr4 = index.close(idx)
  if hits == nil then
    print(("gitboard-find: %s"):format(qerr))
    return 1
  end
  for _, h in ipairs(hits) do
    print(("%s [%s] %s — %s"):format(tail.handle(h.id), h.state, h.title,
        h.snippet))
  end
  print(("gitboard-find: %d hit(s)"):format(#hits))
  return 0
end

local record find
  type Hit = Hit
  type Rows = Rows
  build: function(idx: Index): boolean, string
  query: function(idx: Index, text: string, limit: integer): Rows | nil, string
  similar: function(idx: Index, title: string): Rows | nil, string
  similar_lines: function(s: store.Store, title: string): {string}
  cmd_find: function(s: store.Store, text: string): integer
end

local M: find = {
  build = build,
  query = query,
  similar = similar,
  similar_lines = similar_lines,
  cmd_find = cmd_find,
}

return M
