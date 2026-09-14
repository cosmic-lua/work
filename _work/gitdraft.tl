--- Durable native overlays for board mutations. A draft starts at the fetched
--- canonical state head and retains each speculative transition in order.
--- Its local receipt ref is the restart handle and GC root. Publication keeps
--- the complete commit chain behind one non-forced state update; refresh can
--- consume an already-published prefix while preserving the remaining suffix.
local format = require("_work.format")
local staging = require("_work.statestaging")
local refs = require("_work.refs")

local PREFIX < const > = "refs/gitboard/drafts/"

local record Anchor
  ref: string
  sha: string
end

local record Draft
  native: staging.Receipt
  id: string
  staging_ref: string
  manifest: string
  mode: refs.BoardMode
  remote: string
  anchors: {Anchor}
  updates: {refs.RefUpdate}
end

local function native_draft(root: string, receipt: staging.Receipt): Draft
  local updates: {refs.RefUpdate} = {}
  if #receipt.transitions > 0 then updates = {{ref = "refs/heads/state", expected = receipt.base, next = receipt.tip}} end
  return {native = receipt, id = receipt.id, staging_ref = receipt.ref, manifest = receipt.sha,
    mode = refs.board_mode(root), remote = receipt.remote,
    anchors = {{ref = "refs/heads/state", sha = receipt.base}}, updates = updates}
end

local ACTIVE_BY_ROOT: {string: Draft} = {}

local function valid_id(id: string): boolean
  return #id == 32 and id:match("^[0-9a-f]+$") ~= nil
end
local function read(root: string, staging_ref: string): Draft | nil, string
  local receipt, err = staging.load(root, staging_ref)
  if receipt == nil then return nil, err end
  if receipt.kind ~= "draft" then return nil, "not a native draft" end
  return native_draft(root, receipt), ""
end
local function begin(root: string): Draft | nil, string
  local head, err = format.state_head(root)
  if head == nil then return nil, err end
  local receipt, rerr = staging.create(root, "draft", head, {}, head)
  if receipt == nil then return nil, rerr end
  return native_draft(root, receipt), ""
end

local function open(root: string, id_or_ref: string): Draft | nil, string
  local ref = valid_id(id_or_ref) and (PREFIX .. id_or_ref) or id_or_ref
  return read(root, ref)
end

--- The final state update, from the draft base to its last speculative tip.
local function plan(draft: Draft): {refs.RefUpdate}
  local out: {refs.RefUpdate} = {}
  for _, u in ipairs(draft.updates) do
    out[#out + 1] = {ref = u.ref, expected = u.expected, next = u.next}
  end
  return out
end

local function list(root: string): {Draft} | nil, string
  local found, err = refs.for_each_ref_raw(root, {PREFIX})
  if found == nil then return nil, err end
  local out: {Draft} = {}
  for _, e in ipairs(found) do
    local draft, derr = read(root, e.refname)
    if draft == nil then
      local observed, oerr = refs.read_ref(root, e.refname)
      if observed == nil then return nil, oerr end
      if observed ~= refs.ZERO_SHA then return nil, derr end
    else
      out[#out + 1] = draft
    end
  end
  return out, ""
end

local function abort(root: string, draft: Draft): boolean, string
  return staging.remove(root, draft.native)
end

--- Select a draft for this process and expose its frozen snapshot plus final
--- speculative tips through `_work.refs`. Commit dates are presentation and
--- ordering data, derived in one local Git process; authority remains only the
--- object ids recorded by the manifest.
local function activate(root: string, draft: Draft): boolean, string
  local native = draft.native
  if draft.mode ~= refs.board_mode(root) or native.remote ~= refs.board_remote(root) then
    return false, "draft destination differs"
  end
  staging.activate(root, native)
  refs.set_overlay(root, {{refname = "refs/heads/state", sha = native.tip, touched = os.time()},
      {refname = "refs/heads/board/format", sha = native.tip, touched = os.time()}})
  ACTIVE_BY_ROOT[root] = draft
  return true, ""
end

local function active(root: string): Draft | nil
  return ACTIVE_BY_ROOT[root]
end

local function deactivate(root: string)
  staging.activate(root)
  ACTIVE_BY_ROOT[root] = nil
  refs.clear_overlay(root)
end

local record gitdraft
  type Anchor = Anchor
  type Draft = Draft
  begin: function(root: string): Draft | nil, string
  open: function(root: string, id_or_ref: string): Draft | nil, string
  list: function(root: string): {Draft} | nil, string
  plan: function(draft: Draft): {refs.RefUpdate}
  abort: function(root: string, draft: Draft): boolean, string
  activate: function(root: string, draft: Draft): boolean, string
  active: function(root: string): Draft | nil
  deactivate: function(root: string)
end

local M: gitdraft = {begin = begin, open = open, list = list,
  plan = plan, abort = abort, activate = activate,
  active = active, deactivate = deactivate}

return M
