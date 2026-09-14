--- One native mutation is one immutable commit and one ordered transition.
local boardtree = require("_work.boardtree")
local fastimport = require("_work.fastimport")
local ksuid = require("_work.ksuid")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local store = require("_work.store")
local workspace = require("_work.snapshot_workspace")
local tx = require("_work.statetransaction")

--- Turn one mutation into one immutable commit and one frozen transition: the
--- fence from what this invocation read to decide, the message with its
--- reserved trailers bound, the bounded gate re-checked against the staging
--- base before anything is written, the commit itself, and the receipt that
--- keeps all of it publishable. Nothing here touches `refs/heads/state`:
--- publication is `_work.statepublish`'s.
--- @param s store.Store An open store on a format-6 board
--- @param changes {tx.Change} The paths this mutation writes or deletes
--- @param message string The commit subject and body, before trailers
--- @param publish_by integer | nil A claim batch's deadline, 0 for none
--- @param gate string | nil The gate to re-run when this mutation is bounded
--- @return boolean True on success, including the no-op success
--- @return string The no-op message, or the refusal
local function transition(s: store.Store, changes: {tx.Change}, message: string,
    _publish_by?: integer, _gate?: string): boolean, string
  if #changes == 0 then return true, store.NOOP_PREFIX .. message .. " leaves the board unchanged" end
  if s.state_head == "" then return false, "native transition requires format 6" end
  local canonical, cerr = workspace.canonical_head(s.root)
  if canonical == nil then return false, cerr end
  local tip, err = workspace.compose(s.root, canonical, s.state_head,
    s.session, changes, message)
  if tip == nil then return false, err end
  s.state_head = tip
  s.state_receipt = tip ~= canonical and workspace.REF or ""
  for path in pairs(s.state_reads) do
    local oid, oerr = boardtree.path_id(s.root, tip, path)
    if oid == nil then return false, oerr end
    s.state_reads[path], s.state_paths[path] = oid, oid
  end
  s.bounded = false
  s.written_at = os.time()
  s.fresh_lease = ""
  return true, ""
end

--- Fence one canonical path at the staging base, using an OID a whole-board
--- read already loaded when available.
local function observe_path(s: store.Store, path: string): boolean, string
  if s.state_reads[path] ~= nil then return true, "" end
  local known = s.state_paths[path]
  if known ~= nil then s.state_reads[path] = known
  else
    local oid, err = boardtree.path_id(s.root, s.state_head, path)
    if oid == nil then return false, err end
    s.state_paths[path], s.state_reads[path] = oid, oid
  end
  return true, ""
end

--- Fence both of an item's canonical paths at the staging base.
--- @param s store.Store The store, whose `state_reads` this records into
--- @param id string The item id about to be written
--- @return boolean True when both paths are fenced
--- @return string Error message
local function observe(s: store.Store, id: string): boolean, string
  for _, path in ipairs({"items/" .. id, "claims/" .. id}) do
    local ok, err = observe_path(s, path)
    if not ok then return false, err end
  end
  return true, ""
end
--- One item edit (with any `also` items) as a transition: the paths come from
--- the same fast-import diff the ref layout uses, against the item as OBSERVED,
--- so an unchanged field writes nothing and an unchanged item is a no-op.
--- @param s store.Store An open store on a format-6 board
--- @param it item.Item The item as the verb left it
--- @param message string The commit subject
--- @param spec itemtree.Spec | nil Replacement prose for `it`, nil to leave it
--- @param also {item.Item} | nil Further items this mutation writes
--- @return boolean True on success, including the no-op success
--- @return string The no-op message, or the refusal
local function save(s: store.Store, it: item.Item, message: string, spec?: itemtree.Spec,
    also?: {item.Item}): boolean, string
  local batch: {item.Item} = {it}
  for _, other in ipairs(also or {}) do batch[#batch + 1] = other end
  local changes: {tx.Change} = {}
  for i, x in ipairs(batch) do
    local ok, err = store.stage(s, x)
    if not ok then return false, err end
    local observed, oerr = observe(s, x.id)
    if not observed then return false, oerr end
    local old = s.leased_item[x.id]
    local new = store.snapshot_item(x)
    if new == nil then return false, "cannot snapshot item" end
    new.claim_batch = nil
    if old ~= nil then old = store.snapshot_item(old); old.claim_batch = nil end
    local replacement: itemtree.Spec = nil
    local previous: itemtree.Spec = {change = "", non_goals = ""}
    if i == 1 then replacement = spec end
    if replacement ~= nil and old ~= nil then previous = store.read_spec(s, x.id) end
    for _, op in ipairs(fastimport.diff_item(old, new, replacement, previous)) do
      changes[#changes + 1] = {path = "items/" .. x.id .. "/" .. op.path,
        mode = "100644", content = op.content or "", delete = op.content == nil}
    end
  end
  local ok, err = transition(s, changes, message)
  if not ok or store.is_noop(err) then return ok, err end
  for _, x in ipairs(batch) do
    s.leased_item[x.id] = store.snapshot_item(x)
    s.leased_ref[x.id] = "refs/heads/state"
    s.leased_sha[x.id] = s.state_head
  end
  return true, ""
end
--- A log entry: `items/<id>/log/<ksuid>.md` carrying the prose AND the same
--- text in the commit body, so `git log -- items/<id>` and the tree both show
--- it. The path is what makes the entry an event the reader can attribute.
--- @param s store.Store An open store on a format-6 board
--- @param it item.Item The item the entry belongs to
--- @param subject string The commit subject
--- @param prose string The entry's text
--- @return boolean True on success
--- @return string The refusal
local function log(s: store.Store, it: item.Item, subject: string, prose: string): boolean, string
  local ok, err = observe(s, it.id)
  if not ok then return false, err end
  local id = ksuid.new()
  return transition(s, {{path = "items/" .. it.id .. "/log/" .. id .. ".md", mode = "100644",
        content = prose, delete = false}}, subject .. "\n\n" .. prose)
end
local record Module
  transition: function(s: store.Store, changes: {tx.Change}, message: string, publish_by?: integer, gate?: string): boolean, string
  observe_path: function(store.Store, string): boolean, string
  observe: function(store.Store, string): boolean, string
  save: function(s: store.Store, it: item.Item, message: string, spec?: itemtree.Spec, also?: {item.Item}): boolean, string
  log: function(store.Store, item.Item, string, string): boolean, string
end
local M: Module = {transition = transition, observe_path = observe_path,
  observe = observe, save = save, log = log}
return M
