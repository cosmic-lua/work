--- Native board projections shared by store, cache, and history readers.
local stateread_clock = require("_work.stateread_clock")
local boardread = require("_work.boardread")
local boardhistory = require("_work.boardhistory")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")

--- Fill a fresh index's native tables from one head: the `state_paths` row per
--- item (its subtree and claim ids) and the path-attributed `events` rows. The
--- view and history are parameters so a caller that already read them — a
--- rebuild always has — pays for neither a second time.
--- @param db sqlite.Database The index being rebuilt, inside its transaction
--- @param root string The repository holding `head`
--- @param head string The exact commit being projected
--- @param known_view boardread.View | nil A projection already read
--- @param known_history boardhistory.History | nil A history already read
--- @return boolean True on success
--- @return string Error message
local function fill_events(db: sqlite.Database, root: string, head: string,
    known_view?: boardread.View, known_history?: boardhistory.History): boolean, string
  local history = known_history
  if history == nil then
    local read_history, err = boardhistory.read(root, head)
    if read_history == nil then return false, err end
    history = read_history
  end
  local view = known_view
  if view == nil then
    local read_view, err = boardread.list(root, head)
    if read_view == nil then return false, err end
    view = read_view
  end
  local seqs: {string: integer} = {}
  return db:transaction(function(tx: sqlite.Database): boolean, string
      for _, it in ipairs(view.items) do
        local ok, ierr = tx:exec("INSERT INTO state_paths(path,oid) VALUES (?,?),(?,?)",
          {"items/" .. it.id, view.item_tree_by_id[it.id],
            "claims/" .. it.id, view.claim_blob_by_id[it.id] or refs.ZERO_SHA})
        if not ok then return false, ierr end
      end
      for _, e in ipairs(history.events) do
        seqs[e.item] = (seqs[e.item] or 0) + 1
        local ok, ierr = tx:exec("INSERT INTO events(item,seq,sha,at,verb,session,pr,subject) "
          .. "SELECT ?,?,?,?,?,?,?,? WHERE EXISTS (SELECT 1 FROM items WHERE id=?)",
          {e.item, seqs[e.item], e.sha, e.at, e.verb, e.session, e.pr, e.subject, e.item})
        if not ok then return false, ierr end
      end
      return stateread_clock.record_projection(tx, view)
    end)
end

--- The two fenced path ids for each named item at `head`, an absent path as
--- the zero id — one whole-board read for the batch rather than one per item.
--- @param root string The repository holding `head`
--- @param head string The exact commit to read
--- @param ids {string} Item ids
--- @return {string: string} | nil Path -> object id for every id given
--- @return string Error message
local function paths(root: string, head: string, ids: {string}): {string: string} | nil, string
  local view, err = boardread.list(root, head)
  if view == nil then return nil, err end
  local out: {string: string} = {}
  for _, id in ipairs(ids) do
    out["items/" .. id] = view.item_tree_by_id[id] or refs.ZERO_SHA
    out["claims/" .. id] = view.claim_blob_by_id[id] or refs.ZERO_SHA
  end
  return out, ""
end

return {fill_events = fill_events, paths = paths}
