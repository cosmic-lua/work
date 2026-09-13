--- One native mutation is one immutable commit and one ordered transition.
local codec = require("cosmic.codec")
local rand = require("cosmic.rand")
local fastimport = require("_work.fastimport")
local boardtree = require("_work.boardtree")
local ksuid = require("_work.ksuid")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local refs = require("_work.refs")
local store = require("_work.store")
local projection = require("_work.stateplan_git")
local tx = require("_work.statetransaction")
local stategate = require("_work.stategate")
local staging = require("_work.statestaging")

local function transition(s: store.Store, changes: {tx.Change}, message: string,
    publish_by?: integer, gate?: string): boolean, string
  if #changes == 0 then return true, store.NOOP_PREFIX .. message .. " leaves the board unchanged" end
  if s.state_head == "" then return false, "native transition requires format 6" end
  local receipt = staging.active(s.root)
  if s.state_receipt ~= "" then
    local loaded, err = staging.load(s.root, s.state_receipt)
    if loaded == nil then return false, err end
    receipt = loaded
  end
  local dependencies: {tx.Dependency} = {}
  for path, id in pairs(s.state_reads) do dependencies[#dependencies + 1] = {path = path, id = id} end
  table.sort(dependencies, function(a: tx.Dependency, b: tx.Dependency): boolean return a.path < b.path end)
  local identity = receipt ~= nil and receipt.id or codec.encode_hex(rand.bytes(16))
  local name = s.session ~= "" and s.session or "gitboard"
  local now = fastimport.git_date_now()
  local body = message
  if s.op ~= "" then body = body .. "\n\nOp: " .. s.op end
  local bounded = s.bounded or s.op == "depend" or s.op == "attach"
  local change: tx.Transition = {base = s.state_head, dependencies = dependencies, changes = changes,
    message = body, author = {name = name, email = name .. "@board", date = now},
    publish_by = publish_by or 0, bounded = bounded, gate = gate or (bounded and s.op or "")}
  local frozen, err = tx.freeze({format = tx.FORMAT, repository = staging.repository(s.root, refs.board_remote(s.root)),
      branch = "state", remote = refs.board_remote(s.root), transaction = identity,
      staging_sha = s.state_head, transitions = {change}})
  if frozen == nil then return false, err end
  change = frozen.transitions[1]
  if bounded then
    local allowed, gerr = stategate.check(s.root, s.state_head, change)
    if not allowed then return false, gerr end
  end
  local ops: {fastimport.Op} = {}
  for _, op in ipairs(changes) do ops[#ops + 1] = {path = op.path, content = not op.delete and op.content or nil} end
  local temporary = "refs/gitboard/staging/" .. codec.encode_hex(rand.bytes(16))
  local written, werr = fastimport.run(s.root, {{ref = temporary, from = s.state_head,
        author_name = name, author_email = name .. "@board", author_date = now,
        committer_name = "gitboard", committer_email = "gitboard@board", committer_date = now,
        message = body .. "\n\nTransaction: " .. identity, op = "", ops = ops}})
  if not written then return false, werr end
  local tip, terr = refs.read_ref(s.root, temporary)
  if tip == nil or tip == refs.ZERO_SHA then return false, terr end
  local captured, cerr = projection.capture(s.root, s.state_head, tip, dependencies, publish_by or 0, bounded, change.gate)
  if captured == nil then return false, cerr end
  change = captured
  local next_receipt: staging.Receipt = nil
  if receipt ~= nil then
    local transitions: {tx.Transition} = {}
    for _, old in ipairs(receipt.transitions) do transitions[#transitions + 1] = old end
    transitions[#transitions + 1] = change
    next_receipt, err = staging.write(s.root, {format = receipt.format, id = receipt.id, transaction = receipt.transaction, kind = receipt.kind,
        ref = receipt.ref, sha = receipt.sha, base = receipt.base, tip = tip, remote = receipt.remote,
        target_url = receipt.target_url, repository = receipt.repository, transitions = transitions, published = ""}, receipt.sha)
  else
    next_receipt, err = staging.create(s.root, "prepared", s.state_head, {change}, tip, identity)
  end
  if next_receipt == nil then return false, err end
  local removed, rerr = refs.update_ref(s.root, temporary, refs.ZERO_SHA, tip)
  if not removed then return false, rerr end
  s.state_head = tip
  s.state_receipt = next_receipt.ref
  if next_receipt.kind == "draft" then
    staging.activate(s.root, next_receipt)
    refs.set_overlay(s.root, {{refname = "refs/heads/state", sha = tip, touched = os.time()},
        {refname = "refs/heads/board/format", sha = tip, touched = os.time()}})
  end
  for path in pairs(s.state_reads) do
    local oid, oerr = boardtree.path_id(s.root, tip, path)
    if oid == nil then return false, oerr end
    s.state_reads[path] = oid
  end
  s.bounded = false
  s.written_at = fastimport.git_date_seconds(now)
  s.fresh_lease = ""
  return true, ""
end

local function observe(s: store.Store, id: string): boolean, string
  for _, path in ipairs({"items/" .. id, "claims/" .. id}) do
    if s.state_reads[path] == nil then
      local oid, err = boardtree.path_id(s.root, s.state_head, path)
      if oid == nil then return false, err end
      s.state_reads[path] = oid
    end
  end
  return true, ""
end
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
local function log(s: store.Store, it: item.Item, subject: string, prose: string): boolean, string
  local ok, err = observe(s, it.id)
  if not ok then return false, err end
  local id = ksuid.new()
  return transition(s, {{path = "items/" .. it.id .. "/log/" .. id .. ".md", mode = "100644",
        content = prose, delete = false}}, subject .. "\n\n" .. prose)
end
local record Module
  transition: function(s: store.Store, changes: {tx.Change}, message: string, publish_by?: integer, gate?: string): boolean, string
  observe: function(store.Store, string): boolean, string
  save: function(s: store.Store, it: item.Item, message: string, spec?: itemtree.Spec, also?: {item.Item}): boolean, string
  log: function(store.Store, item.Item, string, string): boolean, string
end
local M: Module = {transition = transition, observe = observe, save = save, log = log}
return M
