--- Durable format-6 preparation and draft receipts. Every receipt retains its
--- speculative tip as a parent, and freezes the complete ordered transition chain.
local codec = require("cosmic.codec")
local rand = require("cosmic.rand")
local child = require("cosmic.child")
local literal = require("_work.singlehead_literal")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")
local tx = require("_work.statetransaction")
local record Receipt
  format: string
  id: string
  transaction: string
  kind: string
  ref: string
  sha: string
  base: string
  tip: string
  remote: string
  target_url: string
  repository: string
  transitions: {tx.Transition}
  published: string
end
local ACTIVE: {string: Receipt} = {}
local function active(root: string): Receipt | nil
  return ACTIVE[root]
end
local function activate(root: string, receipt?: Receipt)
  ACTIVE[root] = receipt
end
local VERSION < const > = "gitboard-state-staging-v1"
local function target_url(root: string, remote: string): string
  local result = child.run({"git", "remote", "get-url", "--push", remote}, {cwd = root})
  if result == nil or not result.ok then return "" end
  return (result.stdout:gsub("%s+$", ""))
end
local function repository(root: string, remote: string): string
  local configured = child.run({"git", "config", "--get", "gitboard.repository"}, {cwd = root})
  if configured ~= nil and configured.ok then return (configured.stdout:gsub("%s+$", "")) end
  local url = child.run({"git", "remote", "get-url", remote}, {cwd = root})
  if url ~= nil and url.ok then
    local name = url.stdout:gsub("%s+$", ""):gsub("%.git$", ""):match("[:/]([^/:]+/[^/]+)$")
    if name ~= nil then return name end
  end
  return "local/board"
end
local function frozen(receipt: Receipt): tx.Frozen | nil, string
  return tx.freeze({format = tx.FORMAT, repository = receipt.repository, branch = "state",
      remote = receipt.remote, transaction = receipt.transaction, staging_sha = receipt.tip,
      transitions = receipt.transitions})
end
local function write(root: string, receipt: Receipt, expected: string): Receipt | nil, string
  local copy: Receipt = {format = VERSION, id = receipt.id, kind = receipt.kind,
    transaction = receipt.transaction, ref = receipt.ref, sha = "", base = receipt.base, tip = receipt.tip, remote = receipt.remote,
    target_url = receipt.target_url, repository = receipt.repository, transitions = receipt.transitions, published = receipt.published}
  if #copy.transitions > 0 then
    local checked, err = frozen(copy)
    if checked == nil then return nil, err end
    copy.transitions = checked.transitions
  end
  local raw, err = literal.encode(copy)
  if raw == nil then return nil, err end
  local blob, berr = gitobj.hash_object_write(root, raw)
  if blob == nil then return nil, berr end
  local tree, terr = gitobj.mktree_write(root, {{mode = "100644", otype = "blob", sha = blob, name = "manifest"}})
  if tree == nil then return nil, terr end
  local sha, serr = gitobj.commit_tree(root, {tree = tree, parents = {copy.tip},
      message = "retain state " .. copy.kind .. " " .. copy.id, author_name = "gitboard",
      author_email = "gitboard@board", committer_name = "gitboard", committer_email = "gitboard@board"})
  if sha == nil then return nil, serr end
  local moved, merr = refs.update_ref(root, copy.ref, sha, expected)
  if not moved then return nil, merr end
  copy.sha = sha
  return copy, ""
end
local function create(root: string, kind: string, base: string,
    transitions: {tx.Transition}, tip: string, id?: string): Receipt | nil, string
  local identity = id or codec.encode_hex(rand.bytes(16))
  local remote = refs.board_remote(root)
  return write(root, {format = VERSION, id = identity, transaction = identity, kind = kind,
      ref = "refs/gitboard/" .. (kind == "draft" and "drafts" or "prepared") .. "/" .. identity,
      sha = "", base = base, tip = tip, remote = remote, target_url = target_url(root, remote), repository = repository(root, remote),
      transitions = transitions, published = ""}, refs.ZERO_SHA)
end
local function read(root: string, ref: string): Receipt | nil, string
  local sha, err = refs.read_ref(root, ref)
  if sha == nil or sha == refs.ZERO_SHA then return nil, err ~= "" and err or "state receipt disappeared" end
  local objects, oerr = gitobj.cat_file_batch(root, {sha .. ":manifest"})
  if objects == nil then return nil, oerr end
  local blob = objects[sha .. ":manifest"]
  if blob == nil or blob.otype ~= "blob" then return nil, "missing state receipt manifest" end
  local value, verr = literal.decode_object(blob.content)
  if value == nil then return nil, verr end
  local receipt = value as Receipt -- cast: discriminant and frozen nested transitions validated below
  if receipt.format ~= VERSION or receipt.ref ~= ref or receipt.sha ~= "" then return nil, "invalid state receipt" end
  if #receipt.transitions > 0 then
    local checked, cerr = frozen(receipt)
    if checked == nil then return nil, cerr end
  end
  receipt.sha = sha
  return receipt, ""
end
local function list(root: string, kind?: string): {Receipt} | nil, string
  local patterns: {string} = {"refs/gitboard/prepared/", "refs/gitboard/drafts/"}
  if kind ~= nil then patterns = {"refs/gitboard/" .. (kind == "draft" and "drafts" or "prepared") .. "/"} end
  local entries, err = refs.for_each_ref_raw(root, patterns)
  if entries == nil then return nil, err end
  local out: {Receipt} = {}
  for _, entry in ipairs(entries) do
    local receipt, rerr = read(root, entry.refname)
    if receipt == nil then return nil, rerr end
    out[#out + 1] = receipt
  end
  return out, ""
end
local function snapshot(root: string, receipt: Receipt): Receipt | nil, string
  if receipt.kind ~= "draft" then return receipt, "" end
  local identity = receipt.id .. "-" .. codec.encode_hex(rand.bytes(8))
  return write(root, {format = VERSION, id = identity, transaction = receipt.transaction,
      kind = "prepared", ref = "refs/gitboard/prepared/" .. identity, sha = "", base = receipt.base,
      tip = receipt.tip, remote = receipt.remote, target_url = receipt.target_url, repository = receipt.repository,
      transitions = receipt.transitions, published = ""}, refs.ZERO_SHA)
end
local function remove(root: string, receipt: Receipt): boolean, string
  return refs.update_ref(root, receipt.ref, refs.ZERO_SHA, receipt.sha)
end
local record Module
  type Receipt = Receipt
  target_url: function(string, string): string
  snapshot: function(string, Receipt): Receipt | nil, string
  active: function(string): Receipt | nil
  activate: function(root: string, receipt?: Receipt)
  repository: function(string, string): string
  frozen: function(Receipt): tx.Frozen | nil, string
  write: function(string, Receipt, string): Receipt | nil, string
  create: function(root: string, kind: string, base: string, transitions: {tx.Transition}, tip: string, id?: string): Receipt | nil, string
  load: function(string, string): Receipt | nil, string
  list: function(root: string, kind?: string): {Receipt} | nil, string
  remove: function(string, Receipt): boolean, string
end
local M: Module = {target_url = target_url, snapshot = snapshot, active = active, activate = activate, repository = repository, frozen = frozen, write = write, create = create, load = read, list = list, remove = remove}
return M
