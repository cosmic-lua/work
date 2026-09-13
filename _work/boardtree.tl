--- Native format-6 board tree codec. Structured records use the same
--- non-executable canonical literal codec as the single-head transport.
local child = require("cosmic.child")
local codec = require("cosmic.codec")
local rand = require("cosmic.rand")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local wire = require("_work.singlehead_literal")

local ZERO_SHA < const > = ("0"):rep(40)

local record boardtree
  record Claim
    id: string holder: string acquired_at: integer renewed_at: integer
    expires_at: integer product_base: string
  end
  record Entry path: string mode: string sha: string end
  ZERO_SHA: string
  mint_claim_id: function(): string
  encode_claim: function(Claim): string | nil, string
  decode_claim: function(string): Claim | nil, string
  encode_marks: function({string: string}): string | nil, string
  decode_marks: function(string): {string: string} | nil, string
  build_item: function(string, item.Item, itemtree.Spec | nil,
  {string: string} | nil, boolean | nil): string | nil, string
  rebuild_item: function(string, item.Item, itemtree.Spec | nil,
  {string: string}, string): string | nil, string
  snapshot_entries: function(string, string): {Entry} | nil, string
  snapshot_tree_entries: function(string, string): {Entry} | nil, string
  path_id: function(string, string, string): string | nil, string
end
local type Claim = boardtree.Claim
local type Entry = boardtree.Entry

local function mint_claim_id(): string
  return codec.encode_hex(rand.bytes(20))
end

local function full_sha(value: any): boolean
  return value is string and #value == 40 and value:match("^[0-9a-f]+$") ~= nil
end

local function encode_claim(st: Claim): string | nil, string
  if not full_sha(st.id) then return nil, "claim id must be a full lowercase hex id" end
  if st.holder == "" then return nil, "claim holder must not be empty" end
  if st.acquired_at > st.renewed_at or st.renewed_at > st.expires_at then
    return nil, "claim timestamps must be ordered"
  end
  return wire.encode({id = st.id, holder = st.holder,
      acquired_at = st.acquired_at, renewed_at = st.renewed_at,
      expires_at = st.expires_at, product_base = st.product_base})
end

local function decode_claim(source: string): Claim | nil, string
  local raw, err = wire.decode_object(source)
  if raw == nil then return nil, err end
  local canonical = wire.encode(raw)
  if canonical == nil or canonical ~= source then return nil, "claim is not canonical literal" end
  for key in pairs(raw) do
    if key ~= "id" and key ~= "holder" and key ~= "acquired_at"
    and key ~= "renewed_at" and key ~= "expires_at" and key ~= "product_base" then
      return nil, "claim has unknown field " .. key
    end
  end
  local rid, holder = raw.id, raw.holder
  local acquired, renewed, expires, product = raw.acquired_at, raw.renewed_at,
  raw.expires_at, raw.product_base
  if not (rid is string) or not full_sha(rid) or not (holder is string)
  or not (acquired is integer) or not (renewed is integer)
  or not (expires is integer) or not (product is string) then
    return nil, "claim has invalid fields"
  end
  local st: Claim = {id = rid, holder = holder,
    acquired_at = acquired, renewed_at = renewed,
    expires_at = expires, product_base = product}
  local _, verr = encode_claim(st)
  if verr ~= nil and verr ~= "" then return nil, verr end
  return st
end

local function encode_marks(marks: {string: string}): string | nil, string
  for old, new in pairs(marks) do
    if not full_sha(old) or not full_sha(new) then
      return nil, "migration marks must map full lowercase hex ids"
    end
  end
  return wire.encode(marks)
end

local function decode_marks(source: string): {string: string} | nil, string
  local raw, err = wire.decode_object(source)
  if raw == nil then return nil, err end
  local canonical = wire.encode(raw)
  if canonical == nil or canonical ~= source then return nil, "marks are not canonical literal" end
  local out: {string: string} = {}
  for old, new in pairs(raw) do
    if not (new is string) or not full_sha(old) or not full_sha(new) then
      return nil, "migration marks must map full lowercase hex ids"
    end
    out[old] = new
  end
  return out
end

local function build_item(root: string, it: item.Item, spec: itemtree.Spec | nil,
    logs?: {string: string}, write?: boolean): string | nil, string
  local claim_batch = it.claim_batch
  it.claim_batch = ""
  local base, err = itemtree.build_tree(root, it, spec, write)
  it.claim_batch = claim_batch
  if base == nil or next(logs or {}) == nil then return base, err end
  local hash = write and gitobj.hash_object_write or gitobj.hash_object
  local mktree = write and gitobj.mktree_write or gitobj.mktree
  local log_entries: {gitobj.TreeEntry} = {}
  for id, content in pairs(logs or {}) do
    local sha, herr = hash(root, content)
    if sha == nil then return nil, herr end
    log_entries[#log_entries + 1] = {mode = "100644", otype = "blob", sha = sha, name = id .. ".md"}
  end
  local log_tree, lerr = mktree(root, log_entries)
  if log_tree == nil then return nil, lerr end
  local got, gerr = gitobj.cat_file_batch(root, {base})
  if got == nil then return nil, gerr end
  local entries = gitobj.parse_tree(got[base].content)
  entries[#entries + 1] = {mode = "40000", otype = "tree", sha = log_tree, name = "log"}
  return mktree(root, entries)
end

--- Pure round-trip rebuild when logs exist. `existing_tree` supplies the
--- materialized non-log entry list; its id without `log` must equal the
--- independently encoded itemtree id before those entries are reused.
local function rebuild_item(root: string, it: item.Item, spec: itemtree.Spec | nil,
    logs: {string: string}, existing_tree: string): string | nil, string
  if next(logs) == nil then return build_item(root, it, spec, nil, false) end
  local claim_batch = it.claim_batch; it.claim_batch = ""
  local expected, err = itemtree.build_tree(root, it, spec, false); it.claim_batch = claim_batch
  if expected == nil then return nil, err end
  local got, gerr = gitobj.cat_file_batch(root, {existing_tree})
  if got == nil or got[existing_tree] == nil then return nil, gerr ~= "" and gerr or "missing item tree" end
  local entries = gitobj.parse_tree(got[existing_tree].content)
  local nonlog: {gitobj.TreeEntry} = {}
  for _, entry in ipairs(entries) do if entry.name ~= "log" then nonlog[#nonlog + 1] = entry end end
  local actual, aerr = gitobj.mktree(root, nonlog)
  if actual == nil then return nil, aerr end
  if actual ~= expected then return nil, "item fields do not encode to existing tree" end
  local log_entries: {gitobj.TreeEntry} = {}
  for id, content in pairs(logs) do
    local sha, herr = gitobj.hash_object(root, content); if sha == nil then return nil, herr end
    log_entries[#log_entries + 1] = {mode = "100644", otype = "blob", sha = sha, name = id .. ".md"}
  end
  local log, lerr = gitobj.mktree(root, log_entries); if log == nil then return nil, lerr end
  nonlog[#nonlog + 1] = {mode = "40000", otype = "tree", sha = log, name = "log"}
  return gitobj.mktree(root, nonlog)
end

local function snapshot_tree_entries(root: string, head: string): {Entry} | nil, string
  local r, err = child.run({"git", "ls-tree", "-r", "-t", "-z", head}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "git ls-tree failed: " .. r.stderr end
  local out: {Entry} = {}
  for row in r.stdout:gmatch("([^\0]+)\0") do
    local mode, _kind, sha, path = row:match("^(%d+) (%S+) (%x+)\t(.*)$")
    if mode ~= nil then out[#out + 1] = {mode = mode, sha = sha, path = path} end
  end
  return out
end

local function snapshot_entries(root: string, head: string): {Entry} | nil, string
  local all, err = snapshot_tree_entries(root, head)
  if all == nil then return nil, err end
  local out: {Entry} = {}
  for _, entry in ipairs(all) do if entry.mode ~= "040000" and entry.mode ~= "40000" then out[#out + 1] = entry end end
  return out
end

local function path_id(root: string, head: string, path: string): string | nil, string
  if path == "" then return gitobj.tree_of(root, head) end
  local r, err = child.run({"git", "rev-parse", "--verify", head .. ":" .. path}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return ZERO_SHA, "" end
  local value = r.stdout:gsub("%s+$", "")
  return value
end

local M: boardtree = {ZERO_SHA = ZERO_SHA, mint_claim_id = mint_claim_id, encode_claim = encode_claim,
  decode_claim = decode_claim, encode_marks = encode_marks, decode_marks = decode_marks,
  build_item = build_item, rebuild_item = rebuild_item, snapshot_entries = snapshot_entries,
  snapshot_tree_entries = snapshot_tree_entries, path_id = path_id}
return M
