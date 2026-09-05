--- The board cache's `events` table, filled and patched from git
--- rather than trusted from anywhere else: an item's history lives
--- only in its commits (every mutation is one commit on the item's
--- ref with a self-describing subject — `take <id8> by <session>
--- pr:N`, `verdict <id8> accept by <session> ...`, `done`, `new`,
--- `attach`, `spec`, `rank`, `set`, `drop` (`_work.gitverbs`/
--- `_work.gitgraph`/`_work.gitverdict`/`_work.gitrank`), and the index
--- carries only an item's CURRENT scalars. `parse_subject` reads that
--- fixed-but-not-total grammar (today's leading tokens plus legacy
--- `move`, `gitboard:`, `board:`, `migrate:`, `work:`, `retitle`,
--- `block`, `compare`, `hold`, `unblock`, `unhold`, `uncompare`,
--- `repo` — none of them refused, every field left at its default on
--- anything unparsed) into
--- `verb`/`session`/`pr`; `walk` fills a rebuild's whole `events`
--- table in one `git log` process; `since` reads one ref's new
--- commits for the fetch patch; `_work.cache` calls `fill_rebuild`,
--- `apply_save`, and `apply_fetch` — the only three entry points it
--- needs, so its own rebuild/save-patch/fetch-patch bodies stay calls
--- rather than a second copy of this module's git and SQL logic (the
--- line cap is why this lives beside `_work.cache` rather than in it).
---
--- COST: measured 2026-09-05 against a throwaway clone of the live
--- board (979 item/ended refs, 7,424 commits — up from the 930/7,163
--- the item's Evidence measured the same day, ordinary board traffic
--- in between). The naive walk — one `git log <ref>` per ref — is
--- O(refs) processes; `walk` instead runs ONE
--- `git log --format='%H\t%ct\t%P\t%s'` over every tip at once and
--- assigns each returned commit to its item by following first-parent
--- chains backward from that item's own tip (sound because no two
--- items ever share a commit — `_work.gitwrite` gives every item its
--- own root history, one linear chain per ref, so a commit reachable
--- from one tip is never reachable from another's). The one process
--- took 120-150ms across repeated runs — the same order as a bare
--- `git log --format='%H %ct %s' $(git for-each-ref ...)` over the
--- same tips (~120ms), so the per-item grouping this module adds on
--- top costs, in practice, nothing beyond the log call itself.
local cachedb = require("_work.cachedb")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

--- One commit subject, parsed: `verb` is the first whitespace token,
--- kept exactly as written (a legacy `gitboard:` or `board:` line
--- keeps its trailing colon — nothing here normalizes the grammar,
--- only reads it); `session` is the token right after a literal
--- ` by `, `""` when the subject carries none; `pr` is the integer
--- right after `pr:`, `0` when absent. A subject this cannot parse at
--- all (an empty commit message, in principle) leaves every field at
--- its zero value rather than refusing — an events row always gets
--- written, classified or not.
local record Subject
  verb: string
  session: string
  pr: integer
end

--- @param subject string A commit subject, verbatim
--- @return Subject The parsed fields
local function parse_subject(subject: string): Subject
  local verb = subject:match("^(%S+)") or ""
  local session = subject:match(" by (%S+)") or ""
  local pr = 0
  local pr_str = subject:match("pr:(%d+)")
  if pr_str ~= nil then
    pr = math.tointeger(tonumber(pr_str)) or 0
  end
  return {verb = verb, session = session, pr = pr}
end

--- One `events` row, exactly as the table stores it — `item`/`seq`
--- are the caller's to set for a row `since` returns (a single ref's
--- range carries no item id of its own to stamp), already filled in
--- for a row `walk` returns.
local record Row
  item: string
  seq: integer
  sha: string
  at: integer
  verb: string
  session: string
  pr: integer
  subject: string
end

--- One parsed log line, before it is known which item (if any) it
--- belongs to.
local record commit
  at: integer
  parent: string
  subject: string
end

--- `git log --format='%H\t%ct\t%P\t%s'` output — full hash, committer
--- epoch, first parent (empty for a root commit), subject, one commit
--- per line — into a sha-keyed map. First parent only: every ref this
--- module ever walks is one `_work.gitwrite` fast-import chain, so a
--- second parent never arises in practice; a merge commit, were one
--- ever found here, would simply have its later parents ignored.
--- @param stdout string The log's raw output
--- @return {string: commit} Every parsed commit, keyed by full sha
local function parse_log(stdout: string): {string: commit}
  local out: {string: commit} = {}
  for line in stdout:gmatch("([^\n]+)") do
    local sha, at_str, parent, subject = line:match("^(%S+)\t(%S+)\t(%S*)\t(.*)$")
    if sha ~= nil then
      out[sha] = {
        at = math.tointeger(tonumber(at_str)) or 0,
        parent = parent,
        subject = subject,
      }
    end
  end
  return out
end

--- One item's full history, oldest first (`seq` 1 is its root `new`),
--- read by following `commits`' first-parent chain backward from
--- `tip` until a commit with no recorded parent (the root) or one this
--- log did not carry (should not happen for a tip this log's own
--- revision list included; a defensive stop rather than an infinite
--- loop either way).
--- @param id string The item id
--- @param tip string Its ref's current sha
--- @param commits {string: commit} Every commit `walk`'s one log call found
--- @return {Row} The item's rows, oldest first
local function chain(id: string, tip: string, commits: {string: commit}): {Row}
  local newest_first: {string} = {}
  local seen: {string: boolean} = {}
  local cur = tip
  while cur ~= "" and commits[cur] ~= nil and not seen[cur] do
    seen[cur] = true
    newest_first[#newest_first + 1] = cur
    cur = commits[cur].parent
  end
  local out: {Row} = {}
  for i = #newest_first, 1, -1 do
    local sha = newest_first[i]
    local c = commits[sha]
    local parsed = parse_subject(c.subject)
    out[#out + 1] = {
      item = id, seq = #newest_first - i + 1, sha = sha, at = c.at,
      verb = parsed.verb, session = parsed.session, pr = parsed.pr,
      subject = c.subject,
    }
  end
  return out
end

--- Every commit on every given item's ref, in one `git log` process
--- regardless of how many items there are — see the module header for
--- the cost this avoids and the soundness argument for grouping by
--- first-parent chain instead of one process per ref.
--- @param root string The store's root
--- @param tips {string: string} Item id -> its ref's current sha
--- (`_work.gitread.list`'s own `board.shas_by_id`, or an equivalent
--- already-deduped snapshot — never re-derived here)
--- @return {Row} | nil Every item's rows, oldest first within an item;
--- possibly empty for an empty board
--- @return string Error message
local function walk(root: string, tips: {string: string}): {Row} | nil, string
  local shas: {string} = {}
  for _, sha in pairs(tips) do
    shas[#shas + 1] = sha
  end
  if #shas == 0 then
    return {}
  end
  table.sort(shas)
  local argv: {string} = {"git", "log", "--format=%H\t%ct\t%P\t%s"}
  for _, sha in ipairs(shas) do
    argv[#argv + 1] = sha
  end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git log failed: %s"):format(r.stderr)
  end
  local commits = parse_log(r.stdout)
  local ids: {string} = {}
  for id in pairs(tips) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  local out: {Row} = {}
  for _, id in ipairs(ids) do
    for _, row in ipairs(chain(id, tips[id], commits)) do
      out[#out + 1] = row
    end
  end
  return out
end

--- One ref's new commits since the cache last saw it — the fetch
--- patch's read: `from_sha..to_sha` when a prior tip is known (an
--- ordinary fast-forward, since nothing here ever rewrites history),
--- or every ancestor of `to_sha` when it is not (a ref this cache has
--- never carried a row for, appearing fresh — `from_sha` "" or
--- `_work.refs.ZERO_SHA`). Rows come back with `item` "" and `seq` 0;
--- the caller — already the one place that knows which item this ref
--- belongs to and where its `events` rows currently top out — fills
--- both in.
--- @param root string The store's root
--- @param from_sha string The previously observed tip, "" or ZERO_SHA for none
--- @param to_sha string The current tip
--- @return {Row} | nil New rows, oldest first; possibly empty
--- @return string Error message
local function since(root: string, from_sha: string, to_sha: string): {Row} | nil, string
  if to_sha == "" then
    return {}
  end
  local rev = to_sha
  if from_sha ~= "" and from_sha ~= refs.ZERO_SHA then
    rev = from_sha .. ".." .. to_sha
  end
  local r, err = child.run(
    {"git", "log", "--format=%H\t%ct\t%P\t%s", rev}, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git log failed: %s"):format(r.stderr)
  end
  local lines: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  local out: {Row} = {}
  for i = #lines, 1, -1 do
    local sha, at_str, _parent, subject = lines[i]:match("^(%S+)\t(%S+)\t(%S*)\t(.*)$")
    if sha ~= nil then
      local parsed = parse_subject(subject)
      out[#out + 1] = {
        item = "", seq = 0, sha = sha, at = math.tointeger(tonumber(at_str)) or 0,
        verb = parsed.verb, session = parsed.session, pr = parsed.pr, subject = subject,
      }
    end
  end
  return out
end

--- One row, written with `db:exec` — the shape every insert into
--- `events` shares, whether from a whole-board `fill_rebuild` or a
--- single patched row.
--- @param db sqlite.Database The connection (or an open transaction)
--- @param row Row The row to write
--- @return boolean True on success
--- @return string Error message
local function insert_row(db: sqlite.Database, row: Row): boolean, string
  return db:exec(
    "INSERT INTO events(item, seq, sha, at, verb, session, pr, subject) "
    .. "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    {row.item, row.seq, row.sha, row.at, row.verb, row.session, row.pr, row.subject})
end

--- Fill `events` for a whole-board rebuild: one `walk` over every
--- item's tip, then one `INSERT` per row. Called after `EXTRA_DDL` has
--- created the table (`_work.cache.rebuild`'s own ordering), inside
--- the same connection `rebuild` is about to rename into place.
--- @param db sqlite.Database The (not yet renamed) rebuild connection
--- @param root string The store's root
--- @param tips {string: string} Item id -> its ref's current sha
--- @return boolean True on success
--- @return string Error message
local function fill_rebuild(db: sqlite.Database, root: string,
    tips: {string: string}): boolean, string
  local rows, err = walk(root, tips)
  if rows == nil then
    return false, err
  end
  for _, row in ipairs(rows) do
    local ok, ierr = insert_row(db, row)
    if not ok then
      return false, ierr
    end
  end
  return true, ""
end

--- Append one row for a save that just wrote a new commit — no git
--- read at all: the caller (`_work.cache.after_save`) already holds
--- everything a row needs. `at` is the patching process's own wall
--- clock, not the exact value `_work.fastimport.git_date_now()` baked
--- into the commit a moment earlier (that value never leaves
--- `_work.gitwrite`) — the two agree to the second in every ordinary
--- case, and any drift a rare scheduling hiccup left behind is
--- self-healing: the next rebuild this ref's digest change triggers
--- recomputes `at` from the commit itself via `walk`.
--- @param tx sqlite.Database The open transaction
--- @param item_id string The item the commit was written to
--- @param sha string The new commit's sha
--- @param at integer The patching process's current wall-clock time
--- @param subject string The commit's subject, verbatim
--- @return boolean True on success
--- @return string Error message
local function apply_save(tx: sqlite.Database, item_id: string, sha: string,
    at: integer, subject: string): boolean, string
  local row, qerr = tx:query_one(
    "SELECT COALESCE(MAX(seq), 0) AS m FROM events WHERE item = ?", {item_id})
  if row == nil and qerr ~= "" then
    return false, qerr
  end
  local next_seq = 1
  if row ~= nil then
    next_seq = (math.tointeger(row.m as number) or 0) + 1 -- cast: from any (sqlite row)
  end
  local parsed = parse_subject(subject)
  return insert_row(tx, {item = item_id, seq = next_seq, sha = sha, at = at,
      verb = parsed.verb, session = parsed.session, pr = parsed.pr, subject = subject})
end

--- Append every row a fetch landed on one ref: `since(old, new)`, then
--- one `INSERT` per returned row with `seq` continuing from this
--- item's current max (0 for a ref the cache has never carried a row
--- for, so the new rows start the chain at 1 exactly as `walk` would
--- have numbered them).
--- @param tx sqlite.Database The open transaction
--- @param root string The store's root
--- @param item_id string The item whose ref moved
--- @param old_sha string Its previously observed tip, "" for none
--- @param new_sha string Its current tip
--- @return boolean True on success
--- @return string Error message
local function apply_fetch(tx: sqlite.Database, root: string, item_id: string,
    old_sha: string, new_sha: string): boolean, string
  local rows, err = since(root, old_sha, new_sha)
  if rows == nil then
    return false, err
  end
  if #rows == 0 then
    return true, ""
  end
  local row, qerr = tx:query_one(
    "SELECT COALESCE(MAX(seq), 0) AS m FROM events WHERE item = ?", {item_id})
  if row == nil and qerr ~= "" then
    return false, qerr
  end
  local next_seq = 0
  if row ~= nil then
    next_seq = math.tointeger(row.m as number) or 0 -- cast: from any (sqlite row)
  end
  for _, r in ipairs(rows) do
    next_seq = next_seq + 1
    local ok, ierr = insert_row(tx, {item = item_id, seq = next_seq, sha = r.sha,
        at = r.at, verb = r.verb, session = r.session, pr = r.pr, subject = r.subject})
    if not ok then
      return false, ierr
    end
  end
  return true, ""
end

--- One item's events straight from the cache file, only when it is
--- already current — the same freshness proof `_work.cache.open`
--- checks (schema version, schema fingerprint, ref digest), but never
--- a rebuild on a miss: a stale or absent file returns nil here, which
--- `_work.publish.history` reads as "run `git log` instead." Costs one
--- `for-each-ref` (the freshness digest) plus one indexed SELECT,
--- never a `git log` process of its own — the read this whole module
--- exists to replace.
--- @param root string The store's root
--- @param id string The item id
--- @return {Row} | nil Rows oldest-first (seq ascending); nil when the
--- cache cannot serve this read
local function read(root: string, id: string): {Row} | nil
  local path = cachedb.path_of(root)
  if not fs.is_file(path) then
    return nil
  end
  local db = cachedb.open_conn(path)
  if db == nil then
    return nil
  end
  local fresh = cachedb.fresh_digest(root)
  local expected_fp = cachedb.expected_schema_fingerprint()
  if fresh == nil or cachedb.db_user_version(db) ~= cachedb.SCHEMA_VERSION
  or cachedb.meta_get(db, "refs_digest") ~= fresh
  or expected_fp == nil or cachedb.meta_get(db, "schema_fingerprint") ~= expected_fp then
    local _c, _cerr = db:close()
    return nil
  end
  local rows, _qerr = db:query(
    "SELECT seq, sha, at, verb, session, pr, subject FROM events "
    .. "WHERE item = ? ORDER BY seq", {id})
  if rows == nil then
    local _c, _cerr = db:close()
    return nil
  end
  local out: {Row} = {}
  for row in rows do
    out[#out + 1] = {
      item = id,
      seq = math.tointeger(row.seq as number) or 0, -- cast: from any (sqlite row)
      sha = row.sha as string, -- cast: from any (sqlite row)
      at = math.tointeger(row.at as number) or 0, -- cast: from any (sqlite row)
      verb = row.verb as string, -- cast: from any (sqlite row)
      session = row.session as string, -- cast: from any (sqlite row)
      pr = math.tointeger(row.pr as number) or 0, -- cast: from any (sqlite row)
      subject = row.subject as string, -- cast: from any (sqlite row)
    }
  end
  local ierr = rows:err()
  local _c, _cerr = db:close()
  if ierr then
    return nil
  end
  return out
end

local record events
  type Subject = Subject
  type Row = Row
  parse_subject: function(subject: string): Subject
  walk: function(root: string, tips: {string: string}): {Row} | nil, string
  since: function(root: string, from_sha: string, to_sha: string): {Row} | nil, string
  fill_rebuild: function(db: sqlite.Database, root: string,
  tips: {string: string}): boolean, string
  apply_save: function(tx: sqlite.Database, item_id: string, sha: string,
  at: integer, subject: string): boolean, string
  apply_fetch: function(tx: sqlite.Database, root: string, item_id: string,
  old_sha: string, new_sha: string): boolean, string
  read: function(root: string, id: string): {Row} | nil
end

local M: events = {
  parse_subject = parse_subject,
  walk = walk,
  since = since,
  fill_rebuild = fill_rebuild,
  apply_save = apply_save,
  apply_fetch = apply_fetch,
  read = read,
}

return M
