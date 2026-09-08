--- Durable offline overlays for board mutations. A draft snapshots the
--- caller's canonical (already-fetched) board refs once, then lets dependent
--- mutations extend speculative tips without moving canonical refs. Its one
--- local ref is both the restart handle and the GC root for every staged
--- successor. Publication collapses the history to one leased update per
--- touched ref: original snapshot -> final speculative tip.
local codec = require("cosmic.codec")
local child = require("cosmic.child")
local rand = require("cosmic.rand")
local gitobj = require("_work.gitobj")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local VERSION < const > = "gitboard-draft-v1"
local PREFIX < const > = "refs/gitboard/drafts/"

local record Anchor
  ref: string
  sha: string
end

local record Draft
  id: string
  staging_ref: string
  manifest: string
  mode: refs.BoardMode
  remote: string
  anchors: {Anchor}
  updates: {prepared.Update}
end

local ACTIVE_BY_ROOT: {string: Draft} = {}

local record Decoded
  mode: refs.BoardMode
  remote: string
  anchors: {Anchor}
  updates: {prepared.Update}
end

local function valid_sha(sha: string): boolean
  return #sha == 40 and sha:match("^[0-9a-f]+$") ~= nil
end

local function valid_target(ref: string): boolean
  return ref:match("^refs/heads/items/[%w_%-]+$") ~= nil
  or ref:match("^refs/heads/ended/[%w_%-]+$") ~= nil
  or ref:match("^refs/heads/board/[%w_%-]+$") ~= nil
end

local function valid_id(id: string): boolean
  return #id == 32 and id:match("^[0-9a-f]+$") ~= nil
end

local function sorted_anchors(anchors: {Anchor}): {Anchor} | nil, string
  local out: {Anchor} = {}
  local seen: {string: boolean} = {}
  for _, a in ipairs(anchors) do
    if not valid_target(a.ref) or not valid_sha(a.sha)
    or a.sha == refs.ZERO_SHA then
      return nil, ("invalid draft anchor for %s"):format(tostring(a.ref))
    end
    if seen[a.ref] then return nil, "duplicate draft anchor: " .. a.ref end
    seen[a.ref] = true
    out[#out + 1] = {ref = a.ref, sha = a.sha}
  end
  table.sort(out, function(a: Anchor, b: Anchor): boolean
      return a.ref < b.ref
    end)
  return out, ""
end

local function sorted_updates(updates: {prepared.Update}): {prepared.Update} | nil, string
  local out: {prepared.Update} = {}
  local seen: {string: boolean} = {}
  for _, u in ipairs(updates) do
    if not valid_target(u.ref) or not valid_sha(u.expected)
    or not valid_sha(u.next) or u.next == refs.ZERO_SHA then
      return nil, ("invalid draft update for %s"):format(tostring(u.ref))
    end
    if seen[u.ref] then return nil, "duplicate draft update: " .. u.ref end
    seen[u.ref] = true
    out[#out + 1] = {ref = u.ref, expected = u.expected, next = u.next}
  end
  table.sort(out, function(a: prepared.Update, b: prepared.Update): boolean
      return a.ref < b.ref
    end)
  return out, ""
end

local function encode(mode: refs.BoardMode, remote: string,
    anchors: {Anchor}, updates: {prepared.Update}): string | nil, string
  if remote:match("^[%w._/-]+$") == nil then
    return nil, "draft remote is not safe"
  end
  local aa, aerr = sorted_anchors(anchors)
  if aa == nil then return nil, aerr end
  local uu, uerr = sorted_updates(updates)
  if uu == nil then return nil, uerr end
  local lines: {string} = {VERSION, "", "mode " .. mode, "remote " .. remote}
  for _, a in ipairs(aa) do
    lines[#lines + 1] = ("anchor %s %s"):format(a.sha, a.ref)
  end
  for _, u in ipairs(uu) do
    lines[#lines + 1] = ("update %s %s %s"):format(
      u.expected, u.next, u.ref)
  end
  return table.concat(lines, "\n") .. "\n", ""
end

local function decode(content: string): Decoded | nil, string
  local first, rest = content:match("^([^\n]+)\n\n(.*)$")
  if first ~= VERSION then
    return nil, "not a supported draft manifest"
  end
  local mode: refs.BoardMode | nil = nil
  local remote = ""
  local anchors: {Anchor} = {}
  local updates: {prepared.Update} = {}
  for line in rest:gmatch("([^\n]+)") do
    local kind, tail = line:match("^(%S+) (.*)$")
    if kind == "mode" and tail == "local" then
      mode = "local"
    elseif kind == "mode" and tail == "remote" then
      mode = "remote"
    elseif kind == "remote" then
      remote = tail
    elseif kind == "anchor" then
      local sha, ref = tail:match("^(%S+) (%S+)$")
      if sha == nil then return nil, "malformed draft anchor" end
      anchors[#anchors + 1] = {ref = ref, sha = sha}
    elseif kind == "update" then
      local expected, next_sha, ref = tail:match("^(%S+) (%S+) (%S+)$")
      if expected == nil then return nil, "malformed draft update" end
      updates[#updates + 1] = {ref = ref, expected = expected, next = next_sha}
    else
      return nil, "malformed draft manifest line: " .. line
    end
  end
  if mode == nil or remote == "" then
    return nil, "draft manifest lacks mode or remote"
  end
  local canonical, err = encode(mode, remote, anchors, updates)
  if canonical == nil then return nil, err end
  if canonical ~= content then
    return nil, "draft manifest is not canonical"
  end
  return {mode = mode, remote = remote, anchors = anchors, updates = updates}, ""
end

local function read(root: string, staging_ref: string): Draft | nil, string
  local id = staging_ref:match("^refs/gitboard/drafts/([0-9a-f]+)$")
  if id == nil or not valid_id(id) then
    return nil, "not a draft ref: " .. staging_ref
  end
  local got, err = gitobj.cat_file_batch(root,
    {staging_ref, staging_ref .. ":manifest"})
  if got == nil then return nil, err end
  local commit, blob = got[staging_ref], got[staging_ref .. ":manifest"]
  if commit == nil or commit.otype ~= "commit"
  or blob == nil or blob.otype ~= "blob" then
    return nil, "unreadable draft: " .. staging_ref
  end
  local decoded, derr = decode(blob.content)
  if decoded == nil then return nil, derr end
  local manifest, merr = refs.read_ref(root, staging_ref)
  if manifest == nil or manifest == refs.ZERO_SHA then
    return nil, merr ~= "" and merr or "draft ref disappeared"
  end
  return {id = id, staging_ref = staging_ref, manifest = manifest,
    mode = decoded.mode, remote = decoded.remote, anchors = decoded.anchors,
    updates = decoded.updates}, ""
end

local function write_manifest(root: string, content: string,
    parents: {string}, message: string): string | nil, string
  local blob, berr = gitobj.hash_object_write(root, content)
  if blob == nil then return nil, berr end
  local tree, terr = gitobj.mktree_write(root, {
      {mode = "100644", otype = "blob", sha = blob, name = "manifest"},
    })
  if tree == nil then return nil, terr end
  return gitobj.commit_tree(root, {tree = tree, parents = parents,
      message = message, author_name = "gitboard",
      author_email = "gitboard@board", committer_name = "gitboard",
      committer_email = "gitboard@board"})
end

--- Begin an offline session from one immutable snapshot of every canonical
--- board ref. Remote mode reads only remote-tracking refs and performs no fetch.
local function begin(root: string): Draft | nil, string
  local found, err = refs.for_each_ref(root,
    {"refs/heads/items", "refs/heads/ended", "refs/heads/board"})
  if found == nil then return nil, err end
  local anchors: {Anchor} = {}
  for _, e in ipairs(found) do
    anchors[#anchors + 1] = {ref = e.refname, sha = e.sha}
  end
  local mode, remote = refs.board_mode(root), refs.board_remote(root)
  local content, cerr = encode(mode, remote, anchors, {})
  if content == nil then return nil, cerr end
  -- Object ids written inside a blob do not retain those objects. Parent the
  -- begin receipt to every unique frozen tip so an offline snapshot survives
  -- tracking-ref movement, reflog expiry, and aggressive GC.
  local parents: {string} = {}
  local seen: {string: boolean} = {}
  for _, anchor in ipairs(anchors) do
    if not seen[anchor.sha] then
      seen[anchor.sha] = true
      parents[#parents + 1] = anchor.sha
    end
  end
  local commit, merr = write_manifest(root, content, parents, "begin board draft")
  if commit == nil then return nil, merr end
  local id = codec.encode_hex(rand.bytes(16))
  local staging_ref = PREFIX .. id
  local moved, rerr = refs.update_ref(root, staging_ref, commit, refs.ZERO_SHA)
  if not moved then return nil, rerr end
  return read(root, staging_ref)
end

local function open(root: string, id_or_ref: string): Draft | nil, string
  local ref = valid_id(id_or_ref) and (PREFIX .. id_or_ref) or id_or_ref
  return read(root, ref)
end

local function anchor_map(draft: Draft): {string: string}
  local out: {string: string} = {}
  for _, a in ipairs(draft.anchors) do out[a.ref] = a.sha end
  return out
end

local function update_map(draft: Draft): {string: prepared.Update}
  local out: {string: prepared.Update} = {}
  for _, u in ipairs(draft.updates) do out[u.ref] = u end
  return out
end

--- Read through the overlay: a staged final tip, otherwise the begin snapshot,
--- otherwise zero for a ref which did not exist when the draft began.
local function tip(draft: Draft, target: string): string | nil, string
  if not valid_target(target) then return nil, "not a board ref: " .. target end
  local changed = update_map(draft)[target]
  if changed ~= nil then return changed.next, "" end
  return anchor_map(draft)[target] or refs.ZERO_SHA, ""
end

--- Extend a draft by local CAS. Each input must be based on the speculative
--- tip, while the durable publication lease remains the original anchor.
local function stage(root: string, draft: Draft,
    additions: {prepared.Update}, message?: string): Draft | nil, string
  local live, lerr = read(root, draft.staging_ref)
  if live == nil then return nil, lerr end
  if live.manifest ~= draft.manifest then
    return nil, "draft changed since it was inspected"
  end
  if #additions == 0 then return nil, "stage requires at least one update" end
  local by_ref = update_map(live)
  local anchors = anchor_map(live)
  local new_parents: {string} = {live.manifest}
  local parent_seen: {string: boolean} = {[live.manifest] = true}
  local seen: {string: boolean} = {}
  for _, add in ipairs(additions) do
    if not valid_target(add.ref) or seen[add.ref] then
      return nil, "invalid or duplicate staged ref: " .. tostring(add.ref)
    end
    seen[add.ref] = true
    local prior = by_ref[add.ref]
    local current = prior and prior.next or anchors[add.ref] or refs.ZERO_SHA
    if add.expected ~= current then
      return nil, ("draft tip mismatch for %s: expected %s, got %s")
      :format(add.ref, current, add.expected)
    end
    local baseline = prior and prior.expected or anchors[add.ref] or refs.ZERO_SHA
    by_ref[add.ref] = {ref = add.ref, expected = baseline, next = add.next}
    if not parent_seen[add.next] then
      parent_seen[add.next] = true
      new_parents[#new_parents + 1] = add.next
    end
  end
  local combined: {prepared.Update} = {}
  for _, u in pairs(by_ref) do
    if u.expected ~= u.next then combined[#combined + 1] = u end
  end
  local content, cerr = encode(live.mode, live.remote, live.anchors, combined)
  if content == nil then return nil, cerr end
  local commit, merr = write_manifest(root, content, new_parents,
    message or "extend board draft")
  if commit == nil then return nil, merr end
  local moved, rerr = refs.update_ref(root, live.staging_ref, commit, live.manifest)
  if not moved then return nil, "draft changed while staging: " .. rerr end
  return read(root, live.staging_ref)
end

--- The consolidated publication transaction. It contains one update per
--- touched ref, from the begin snapshot directly to the final overlay tip.
local function plan(draft: Draft): {prepared.Update}
  local out: {prepared.Update} = {}
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
  local live, err = refs.read_ref(root, draft.staging_ref)
  if live == nil then return false, err end
  if live == refs.ZERO_SHA then return true, "" end
  if live ~= draft.manifest then return false, "draft changed since it was inspected" end
  return refs.update_ref(root, draft.staging_ref, refs.ZERO_SHA, draft.manifest)
end

--- Select a draft for this process and expose its frozen snapshot plus final
--- speculative tips through `_work.refs`. Commit dates are presentation and
--- ordering data, derived in one local Git process; authority remains only the
--- object ids recorded by the manifest.
local function activate(root: string, draft: Draft): boolean, string
  if draft.mode ~= refs.board_mode(root) or draft.remote ~= refs.board_remote(root) then
    return false, "draft was opened for a different board mode or remote"
  end
  local tips: {string: string} = {}
  for _, a in ipairs(draft.anchors) do tips[a.ref] = a.sha end
  for _, u in ipairs(draft.updates) do tips[u.ref] = u.next end
  local argv: {string} = {"git", "show", "-s", "--format=%H %ct"}
  for _, sha in pairs(tips) do argv[#argv + 1] = sha end
  local shown, err = child.run(argv, {cwd = root})
  if shown == nil then return false, err end
  if not shown.ok then return false, "could not inspect draft tips: " .. shown.stderr end
  local touched: {string: integer} = {}
  for line in shown.stdout:gmatch("([^\n]+)") do
    local sha, stamp = line:match("^(%x+) (%d+)$")
    if sha ~= nil then touched[sha] = math.tointeger(tonumber(stamp)) or 0 end
  end
  local entries: {refs.RefEntry} = {}
  for ref, sha in pairs(tips) do
    entries[#entries + 1] = {refname = ref, sha = sha, touched = touched[sha] or 0}
  end
  refs.set_overlay(root, entries)
  ACTIVE_BY_ROOT[root] = draft
  return true, ""
end

local function active(root: string): Draft | nil
  return ACTIVE_BY_ROOT[root]
end

local function deactivate(root: string)
  ACTIVE_BY_ROOT[root] = nil
  refs.clear_overlay(root)
end

--- The real local ref value to restore after fast-import temporarily writes a
--- speculative successor. Remote boards normally have no local board heads;
--- local simulation restores the frozen canonical anchor.
local function underlying_tip(draft: Draft, target: string): string
  if draft.mode == "remote" then return refs.ZERO_SHA end
  return anchor_map(draft)[target] or refs.ZERO_SHA
end

local record gitdraft
  type Anchor = Anchor
  type Draft = Draft
  begin: function(root: string): Draft | nil, string
  open: function(root: string, id_or_ref: string): Draft | nil, string
  list: function(root: string): {Draft} | nil, string
  tip: function(draft: Draft, target: string): string | nil, string
  stage: function(root: string, draft: Draft,
  additions: {prepared.Update}, message?: string): Draft | nil, string
  plan: function(draft: Draft): {prepared.Update}
  abort: function(root: string, draft: Draft): boolean, string
  activate: function(root: string, draft: Draft): boolean, string
  active: function(root: string): Draft | nil
  deactivate: function(root: string)
  underlying_tip: function(draft: Draft, target: string): string
end

local M: gitdraft = {begin = begin, open = open, list = list, tip = tip,
  stage = stage, plan = plan, abort = abort, activate = activate,
  active = active, deactivate = deactivate, underlying_tip = underlying_tip}

return M
