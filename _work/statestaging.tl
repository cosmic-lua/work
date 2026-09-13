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
--- The draft receipt this invocation is writing into, when one is activated;
--- nil for an ordinary mutation. Process-local: activating a draft is a
--- decision one invocation makes, never board state.
--- @param root string The board checkout
--- @return Receipt | nil The active draft receipt
local function active(root: string): Receipt | nil
  return ACTIVE[root]
end
--- Make `receipt` the draft this invocation writes into, or clear it when
--- called with none.
--- @param root string The board checkout
--- @param receipt Receipt | nil The draft to activate, nil to deactivate
local function activate(root: string, receipt?: Receipt)
  ACTIVE[root] = receipt
end
local VERSION < const > = "gitboard-state-staging-v1"
--- The exact URL a publication to `remote` would push to, "" when the remote
--- has none. Recorded in the receipt so an attempt frozen for one destination
--- can never be replayed against another.
--- @param root string The board checkout
--- @param remote string The configured board remote
--- @return string The push URL, "" when unknown
local function target_url(root: string, remote: string): string
  local result = child.run({"git", "remote", "get-url", "--push", remote}, {cwd = root})
  if result == nil or not result.ok then return "" end
  return (result.stdout:gsub("%s+$", ""))
end
--- The `owner/name` a publication is bound to: the configured
--- `gitboard.repository` when set, otherwise derived from the remote's URL,
--- and `local/board` for a checkout with neither.
--- @param root string The board checkout
--- @param remote string The configured board remote
--- @return string The repository identity the plan is bound to
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
--- The receipt's chain as a frozen transaction, re-validated on the way out —
--- every read and write of a receipt goes through this, so a manifest whose
--- transitions no longer satisfy the transaction rules is never acted on.
--- @param receipt Receipt The receipt to read the chain from
--- @return tx.Frozen | nil The canonical frozen chain
--- @return string Error message
local function frozen(receipt: Receipt): tx.Frozen | nil, string
  return tx.freeze({format = tx.FORMAT, repository = receipt.repository, branch = "state",
      remote = receipt.remote, transaction = receipt.transaction, staging_sha = receipt.tip,
      transitions = receipt.transitions})
end
--- Persist a receipt as its own commit and move its ref under a
--- compare-and-swap on `expected`, so two writers cannot interleave into one
--- manifest. The commit's parent is the speculative tip, which is what keeps
--- the staged objects alive against garbage collection.
--- @param root string The board checkout
--- @param receipt Receipt The receipt to persist
--- @param expected string The ref's current value, `ZERO_SHA` to create
--- @return Receipt | nil The receipt, with the manifest commit it now names
--- @return string Error message
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
--- A new prepared or draft receipt, bound to this checkout's destination.
--- @param root string The board checkout
--- @param kind string "draft" or anything else for a prepared transaction
--- @param base string The staging base the chain was built from
--- @param transitions {tx.Transition} The chain, possibly empty for a new draft
--- @param tip string The speculative commit the chain ends at
--- @param id string | nil The identity to use, minted when absent
--- @return Receipt | nil The persisted receipt
--- @return string Error message
local function create(root: string, kind: string, base: string,
    transitions: {tx.Transition}, tip: string, id?: string): Receipt | nil, string
  local identity = id or codec.encode_hex(rand.bytes(16))
  local remote = refs.board_remote(root)
  return write(root, {format = VERSION, id = identity, transaction = identity, kind = kind,
      ref = "refs/gitboard/" .. (kind == "draft" and "drafts" or "prepared") .. "/" .. identity,
      sha = "", base = base, tip = tip, remote = remote, target_url = target_url(root, remote), repository = repository(root, remote),
      transitions = transitions, published = ""}, refs.ZERO_SHA)
end
--- One receipt from its ref, refusing a manifest that is not a receipt for
--- exactly this ref or whose chain no longer validates.
--- @param root string The board checkout
--- @param ref string The receipt's ref
--- @return Receipt | nil The receipt
--- @return string Error message; "state receipt disappeared" when the ref is gone
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
--- Every prepared transaction and draft this checkout holds, or just one kind.
--- @param root string The board checkout
--- @param kind string | nil "draft" or "prepared" to narrow, nil for both
--- @return {Receipt} | nil The receipts
--- @return string Error message
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
--- A prepared receipt frozen out of a draft's current chain, so publishing that
--- snapshot is unaffected by the draft advancing afterwards. A receipt that is
--- not a draft is already such a snapshot and is returned unchanged.
--- @param root string The board checkout
--- @param receipt Receipt The draft to snapshot
--- @return Receipt | nil The prepared snapshot
--- @return string Error message
local function snapshot(root: string, receipt: Receipt): Receipt | nil, string
  if receipt.kind ~= "draft" then return receipt, "" end
  local identity = receipt.id .. "-" .. codec.encode_hex(rand.bytes(8))
  return write(root, {format = VERSION, id = identity, transaction = receipt.transaction,
      kind = "prepared", ref = "refs/gitboard/prepared/" .. identity, sha = "", base = receipt.base,
      tip = receipt.tip, remote = receipt.remote, target_url = receipt.target_url, repository = receipt.repository,
      transitions = receipt.transitions, published = ""}, refs.ZERO_SHA)
end
--- Drop a receipt whole after a lost race, keeping it under
--- `refs/gitboard/quarantined/lost-race/<id>` so the attempt stays inspectable
--- and `was_retired` can prove later that it was dropped rather than lost. The
--- move is one transaction, and a receipt that ADVANCED since it was read is
--- refused: retiring a different snapshot than the one that lost would discard
--- work nobody judged.
--- @param root string The board checkout
--- @param receipt Receipt The receipt exactly as it was read
--- @return boolean True when the receipt is retired
--- @return string Error message
local function retire(root: string, receipt: Receipt): boolean, string
  local destination = "refs/gitboard/quarantined/lost-race/" .. receipt.id
  local prior, perr = refs.read_ref(root, destination)
  if prior == nil then return false, perr end
  if prior ~= refs.ZERO_SHA and prior ~= receipt.sha then return false, "lost-race quarantine already names another receipt" end
  local live, lerr = refs.read_ref(root, receipt.ref)
  if live == nil then return false, lerr end
  if live == refs.ZERO_SHA then
    if prior == receipt.sha then return true, "" end
    return false, "receipt disappeared without a matching retirement"
  end
  if live ~= receipt.sha then return false, "receipt advanced; refusing to retire a different snapshot" end
  return refs.update_refs_atomic(root, {
      {ref = destination, expected = prior, next = receipt.sha},
      {ref = receipt.ref, expected = receipt.sha, next = refs.ZERO_SHA}})
end
--- Whether this exact attempt was retired, rather than merely missing — the
--- difference between "a lost race dropped it" and "something else deleted it",
--- which an absent ref alone cannot tell.
--- @param root string The board checkout
--- @param ref string The receipt ref that is now absent
--- @param tip string The speculative tip that receipt named
--- @return boolean True when the quarantine holds exactly this attempt
--- @return string Error message
local function was_retired(root: string, ref: string, tip: string): boolean, string
  local identity = ref:match("^refs/gitboard/prepared/(.+)$") or ref:match("^refs/gitboard/drafts/(.+)$")
  if identity == nil then return false, "" end
  local sha, err = refs.read_ref(root, "refs/gitboard/quarantined/lost-race/" .. identity)
  if sha == nil then return false, err end
  if sha == refs.ZERO_SHA then return false, "" end
  local got, gerr = gitobj.cat_file_batch(root, {sha .. ":manifest"})
  if got == nil then return false, gerr end
  local blob = got[sha .. ":manifest"]
  if blob == nil or blob.otype ~= "blob" then return false, "invalid retired receipt" end
  local decoded, derr = literal.decode_object(blob.content)
  if decoded == nil then return false, derr end
  return decoded.format == VERSION and decoded.ref == ref and decoded.tip == tip, ""
end
--- Delete a receipt's ref under a compare-and-swap on the manifest it named —
--- how a CONFIRMED attempt retires, as against `retire`'s quarantine.
--- @param root string The board checkout
--- @param receipt Receipt The receipt exactly as it was read
--- @return boolean True when the ref is gone
--- @return string Error message
local function remove(root: string, receipt: Receipt): boolean, string
  return refs.update_ref(root, receipt.ref, refs.ZERO_SHA, receipt.sha)
end
local record Module
  type Receipt = Receipt
  retire: function(string, Receipt): boolean, string
  was_retired: function(string, string, string): boolean, string
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
local M: Module = {was_retired = was_retired, retire = retire, target_url = target_url, snapshot = snapshot, active = active, activate = activate, repository = repository, frozen = frozen, write = write, create = create, load = read, list = list, remove = remove}
return M
