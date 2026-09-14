--- One clone-local, replaceable final-board proposal.
local fs = require("cosmic.fs")
local fastimport = require("_work.fastimport")
local git = require("_work.singlehead_git")
local projection = require("_work.stateplan_git")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local tx = require("_work.statetransaction")

local REF < const > = "refs/gitboard/snapshot"

local record Candidate
  commit: string
  parent: string
  claims_changed: boolean
end

local function recovery_path(root: string): string
  local common = git.text(root, {"rev-parse", "--git-common-dir"})
  if common == nil then return fs.join(root, ".git/gitboard/snapshot-recovery.literal") end
  if common:sub(1, 1) ~= "/" then common = fs.join(root, common) end
  return fs.join(common, "gitboard/snapshot-recovery.literal")
end

local function read(root: string): Candidate | nil, string
  local commit, err = refs.read_ref(root, REF)
  if commit == nil then return nil, err end
  if commit == refs.ZERO_SHA then return nil, "" end
  local identity, ierr = snapshot.commit_identity(root, commit)
  if identity == nil then return nil, "invalid local snapshot: " .. ierr end
  local same, _out, derr = git.probe(root,
    {"diff", "--quiet", identity.parent, commit, "--", "claims"})
  if derr ~= "" then return nil, derr end
  return {commit = commit, parent = identity.parent, claims_changed = not same}, ""
end

local function old_inflight(root: string): boolean, string
  local found, err = refs.for_each_ref_raw(root,
    {"refs/gitboard/prepared/", "refs/gitboard/drafts/"})
  if found == nil then return false, err end
  return #found > 0, ""
end

local function recovery_present(path: string): boolean
  return fs.is_present(path) or fs.is_present(path .. ".candidate")
  or fs.is_present(path .. ".updating")
end

local function frozen(root: string, candidate?: Candidate): boolean, string
  local path = recovery_path(root)
  if not recovery_present(path) then return false, "" end
  local recovery = require("_work.snapshot_recovery")
  local state, err = recovery.load(path)
  if state == nil then return false, "cannot inspect frozen snapshot: " .. err end
  if candidate == nil or state.local_commit ~= candidate.commit then
    return false, "a different frozen snapshot must be reconciled before composition"
  end
  return true, ""
end

local function canonical_head(root: string): string | nil, string
  local ref = refs.board_mode(root) == "local" and "refs/heads/state"
  or "refs/remotes/" .. refs.board_remote(root) .. "/state"
  return refs.read_ref(root, ref)
end

--- Select the proposal as this process's read view. A stale proposal remains
--- publishable for conflict diagnosis, but cannot be extended.
local function activate(root: string, allow_frozen?: boolean): Candidate | nil, string
  refs.clear_overlay(root)
  local path = recovery_path(root)
  if recovery_present(path) then
    local recovery = require("_work.snapshot_recovery")
    local state, err = recovery.load(path)
    if state == nil then return nil, "frozen snapshot needs reconciliation: " .. err end
    local candidate, cerr = read(root)
    if candidate == nil then return nil, cerr ~= "" and cerr
      or "frozen snapshot has no retained local composition" end
    if state.local_commit ~= candidate.commit then
      return nil, "a different frozen snapshot must be reconciled before composition"
    end
    if allow_frozen then return nil, "" end
    return nil, "snapshot " .. state.local_commit .. " is frozen for publication; reconcile it first"
  end
  local candidate, err = read(root)
  if candidate == nil then return nil, err end
  -- A locally proposed lease is never authority. Keep every ordinary reader on
  -- the fetched canonical state until that claim snapshot is confirmed.
  if candidate.claims_changed then return candidate, "" end
  refs.set_overlay(root, {
      {refname = "refs/heads/state", sha = candidate.commit, touched = os.time()},
      {refname = "refs/heads/board/format", sha = candidate.commit, touched = os.time()},
    })
  return candidate, ""
end

local function compose(root: string, canonical: string, current: string,
    session: string, changes: {tx.Change}, summary: string): string | nil, string
  local candidate, err = read(root)
  if err ~= "" then return nil, err end
  local locked, lerr = frozen(root, candidate)
  if lerr ~= "" then return nil, lerr end
  if locked then return nil, "snapshot publication has begun; reconcile it before composing more work" end
  if candidate == nil then
    local old, oerr = old_inflight(root)
    if oerr ~= "" then return nil, oerr end
    if old then
      return nil, "REFUSED: obsolete format-6 transaction/draft is still in flight; publish or abandon it with the older gitboard before composing a snapshot"
    end
    if current ~= canonical then return nil, "snapshot composition did not start at canonical state" end
  else
    if candidate.claims_changed then
      return nil, "claim publication must be fetched and confirmed before dependent work"
    end
    if candidate.parent ~= canonical or candidate.commit ~= current then
      return nil, "canonical head or local snapshot changed; reopen the board"
    end
  end
  local tree, terr = projection.apply(root, current, changes)
  if tree == nil then return nil, terr end
  local base_tree, berr = git.oid(root, canonical .. "^{tree}")
  if base_tree == nil then return nil, berr end
  local prior = candidate ~= nil and candidate.commit or refs.ZERO_SHA
  if tree == base_tree then
    if candidate ~= nil then
      local removed, rerr = refs.update_ref(root, REF, refs.ZERO_SHA, prior)
      if not removed then return nil, rerr end
    end
    return canonical, "reverted"
  end
  local name = session ~= "" and session or "gitboard"
  local date = fastimport.git_date_now()
  local author: snapshot.Author = {name = name, email = name .. "@board", date = date}
  if candidate ~= nil then
    local identity, ierr = snapshot.commit_identity(root, candidate.commit)
    if identity == nil then return nil, ierr end
    if identity.author.name ~= author.name or identity.author.email ~= author.email then
      return nil, "snapshot composition belongs to " .. identity.author.name
    end
  end
  local message, merr = snapshot.message(summary, author)
  if message == nil then return nil, merr end
  local commit, cerr = git.text(root, {"commit-tree", tree, "-p", canonical}, message, {
      GIT_AUTHOR_NAME = author.name, GIT_AUTHOR_EMAIL = author.email,
      GIT_AUTHOR_DATE = author.date, GIT_COMMITTER_NAME = "gitboard",
      GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = author.date})
  if commit == nil then return nil, cerr end
  local updated, uerr = refs.update_ref(root, REF, commit, prior)
  if not updated then return nil, uerr end
  return commit, ""
end

local function clear(root: string, expected: string): boolean, string
  return refs.update_ref(root, REF, refs.ZERO_SHA, expected)
end

local function resummary(root: string, summary: string): string | nil, string
  local candidate, err = read(root)
  if candidate == nil then return nil, err ~= "" and err or "no local snapshot" end
  local locked, lerr = frozen(root, candidate)
  if lerr ~= "" then return nil, lerr end
  if locked then return nil, "snapshot publication has begun; its summary is immutable" end
  local identity, ierr = snapshot.commit_identity(root, candidate.commit)
  if identity == nil then return nil, ierr end
  local author: snapshot.Author = {name = identity.author.name,
    email = identity.author.email, date = fastimport.git_date_now()}
  local message, merr = snapshot.message(summary, author)
  if message == nil then return nil, merr end
  local commit, cerr = git.text(root, {"commit-tree", identity.tree, "-p", identity.parent},
    message, {GIT_AUTHOR_NAME = author.name, GIT_AUTHOR_EMAIL = author.email,
      GIT_AUTHOR_DATE = author.date, GIT_COMMITTER_NAME = "gitboard",
      GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = author.date})
  if commit == nil then return nil, cerr end
  local updated, uerr = refs.update_ref(root, REF, commit, candidate.commit)
  if not updated then return nil, uerr end
  return commit, ""
end

local function retain_conflict(root: string, candidate: Candidate): boolean, string
  local ref = "refs/gitboard/conflicts/" .. candidate.commit
  local kept, err = refs.update_ref(root, ref, candidate.commit, refs.ZERO_SHA)
  if not kept then return false, err end
  return clear(root, candidate.commit)
end

local record Module
  type Candidate = Candidate
  REF: string
  recovery_path: function(string): string
  canonical_head: function(string): string | nil, string
  read: function(string): Candidate | nil, string
  activate: function(string, boolean | nil): Candidate | nil, string
  compose: function(string, string, string, string, {tx.Change}, string): string | nil, string
  clear: function(string, string): boolean, string
  resummary: function(string, string): string | nil, string
  retain_conflict: function(string, Candidate): boolean, string
end
local M: Module = {REF = REF, recovery_path = recovery_path,
  canonical_head = canonical_head, read = read,
  activate = activate, compose = compose, clear = clear,
  resummary = resummary, retain_conflict = retain_conflict}
return M
