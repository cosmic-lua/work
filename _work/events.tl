--- Native event subject grammar and the disposable cached audit view.
--- Legacy subject forms remain readable as migration evidence.
local cachedb = require("_work.cachedb")
local fs = require("cosmic.fs")

--- One commit subject, parsed: `verb` is the first whitespace token,
--- kept exactly as written (a legacy `gitboard:` or `board:` line
--- keeps its trailing colon — nothing here normalizes the grammar,
--- only reads it); `session` is the token right after a literal
--- ` by `, `""` when the subject carries none; `head` is the hexadecimal
--- commit id after `head:`, `""` when absent; `pr` is the legacy integer
--- right after `pr:`, `0` when absent. A subject this cannot parse at
--- all (an empty commit message, in principle) leaves every field at
--- its zero value rather than refusing — an events row always gets
--- written, classified or not.
local record Subject
  verb: string
  session: string
  head: string
  pr: integer
end

--- @param subject string A commit subject, verbatim
--- @return Subject The parsed fields
local function parse_subject(subject: string): Subject
  local verb = subject:match("^(%S+)") or ""
  local session = subject:match(" by (%S+)") or ""
  local head = subject:match("head:([0-9a-fA-F]+)") or ""
  local pr = 0
  local pr_str = subject:match("pr:(%d+)")
  if pr_str ~= nil then
    pr = math.tointeger(tonumber(pr_str)) or 0
  end
  return {verb = verb, session = session, head = head:lower(), pr = pr}
end

--- One native path-attributed event row in the query projection.
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
  read: function(root: string, id: string): {Row} | nil
end

local M: events = {
  parse_subject = parse_subject,
  read = read,
}

return M
