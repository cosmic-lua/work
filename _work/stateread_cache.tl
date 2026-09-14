--- Patch the disposable native index from exact item/claim paths and event tips.
local stateread_clock = require("_work.stateread_clock")
local boardread = require("_work.boardread")
local boardhistory = require("_work.boardhistory")
local cachedb = require("_work.cachedb")
local find = require("_work.find")
local fs = require("cosmic.fs")
local index = require("_work.index")
local index_rank = require("_work.index_rank")
local readddl = require("_work.readddl")
local refs = require("_work.refs")
local spec = require("_work.spec")
local sqlite = require("cosmic.sqlite")

--- Move the index from the head it recorded to `head` by rewriting only the
--- items whose subtree, claim blob or tip actually moved — the incremental half
--- of the read model, which is why a fetch of one commit does not cost a full
--- rebuild. Silently does nothing unless the index is valid at `before`: a
--- stale or absent file is left for the next open to rebuild, never patched on
--- trust.
--- @param root string The store's root
--- @param before string | nil The head the index was valid at
--- @param head string The head to move it to
--- @return boolean True when the index is now at `head`, or was left alone
--- @return string Error message
local function patch(root: string, before: string | nil, head: string): boolean, string
  if before == nil or before == "" or before == head or not fs.is_file(cachedb.path_of(root)) then
    return true, ""
  end
  local db, err = cachedb.open_conn(cachedb.path_of(root))
  if db == nil then return false, err end
  if cachedb.meta_get(db, "refs_digest") ~= before
  or cachedb.db_user_version(db) ~= cachedb.SCHEMA_VERSION then
    local _ok, _err = db:close()
    return true, ""
  end
  local view, verr = boardread.list(root, head)
  if view == nil then local _ok, _err = db:close(); return false, verr end
  local history, herr = boardhistory.read(root, head, before)
  if history == nil then
    local _ok, _err = db:close()
    if herr == boardhistory.NOT_FAST_FORWARD then return true, "" end
    return false, herr
  end
  local old: {string: string} = {}
  local rows, rerr = db:query("SELECT path,oid FROM state_paths")
  if rows == nil then local _ok, _err = db:close(); return false, rerr end
  for row in rows do old[row.path as string] = row.oid as string end -- cast: from any (strict SQLite text columns)
  local old_items: {string: string} = {}
  local old_claims: {string: string} = {}
  local old_dates: {string: integer} = {}
  local items, ierr = db:query("SELECT id,tip,claim,touched_at FROM items")
  if items == nil then local _ok, _err = db:close(); return false, ierr end
  for row in items do
    old_items[row.id as string] = row.tip as string -- cast: from any (strict SQLite text columns)
    old_claims[row.id as string] = row.claim as string -- cast: from any (strict SQLite text columns)
    old_dates[row.id as string] = row.touched_at as integer -- cast: strict SQLite integer column
  end
  local sequences: {string: integer} = {}
  local seq_rows, serr = db:query("SELECT item,MAX(seq) AS seq FROM events GROUP BY item")
  if seq_rows == nil then local _ok, _err = db:close(); return false, serr end
  for row in seq_rows do
    sequences[row.item as string] = row.seq as integer -- cast: strict SQLite sequence column
  end
  local changed: {string: boolean} = {}
  for _, it in ipairs(view.items) do
    if old_items[it.id] ~= (history.tip_by_id[it.id] or old_items[it.id]) or old_claims[it.id] ~= (it.claim or "")
    or old["items/" .. it.id] ~= view.item_tree_by_id[it.id]
    or old["claims/" .. it.id] ~= (view.claim_blob_by_id[it.id] or refs.ZERO_SHA) then
      changed[it.id] = true
    end
  end
  for id in pairs(old_items) do
    if view.items_by_id[id] == nil then changed[id] = true end
  end
  local ok, perr = db:transaction(function(tx: sqlite.Database): boolean, string
      local c: cachedb.Cache = {db = tx, specs = {}, load_problems = {}}
      for id in pairs(changed) do
        local deleted, derr = tx:exec("DELETE FROM state_paths WHERE path IN (?,?)", {"items/" .. id, "claims/" .. id})
        if not deleted then return false, derr end
        local it = view.items_by_id[id]
        if it == nil then
          deleted, derr = tx:exec("DELETE FROM events WHERE item=?", {id})
          if not deleted then return false, derr end
          deleted, derr = index.delete_item(tx, id)
          if deleted then deleted, derr = find.remove_item(c, id) end
          if not deleted then return false, derr end
        else
          local patched, paerr = cachedb.patch_item(c, it, spec.document(view.specs_by_id[id]),
            {ref = "refs/heads/state", tip = history.tip_by_id[id] or old_items[id] or head,
              touched_at = history.touched_by_id[id] or old_dates[id] or 0})
          if not patched then return false, paerr end
          patched, paerr = tx:exec("INSERT INTO state_paths(path,oid) VALUES (?,?),(?,?)",
            {"items/" .. id, view.item_tree_by_id[id], "claims/" .. id, view.claim_blob_by_id[id] or refs.ZERO_SHA})
          if not patched then return false, paerr end
          for seq, ev in ipairs(history.events_by_id[id] or {}) do
            patched, paerr = tx:exec("INSERT INTO events(item,seq,sha,at,verb,session,pr,subject) VALUES (?,?,?,?,?,?,?,?)",
              {id, (sequences[id] or 0) + seq, ev.sha, ev.at, ev.verb, ev.session, ev.pr, ev.subject})
            if not patched then return false, paerr end
          end
        end
      end
      local rebuilt, reerr = index_rank.refill(c)
      if rebuilt then rebuilt, reerr = readddl.refill_role(c) end
      if rebuilt then rebuilt, reerr = stateread_clock.record_projection(tx, view) end
      if rebuilt then rebuilt, reerr = cachedb.meta_set(tx, "refs_digest", head) end
      return rebuilt, reerr
    end)
  local _closed, _cerr = db:close()
  return ok, perr
end
return {patch = patch}
