--- Ref plumbing: reading `refs/heads/items/*`, `refs/heads/ended/*` and
--- `refs/heads/board/*` with `for-each-ref`, moving one ref with
--- `update-ref` (a single compare-and-swap, or a `--stdin`
--- transaction for the ended-item move), and pushing every ref one
--- save touched in a single atomic, leased push. `_work.gitobj` is
--- the object half; this is the naming half, and `_work.store` is the
--- only caller outside tests.
local child = require("cosmic.child")

--- The sha `update-ref`/`--force-with-lease` treat as "does not exist
--- yet" — a brand-new ref's lease value.
local ZERO_SHA < const > = ("0"):rep(40)

--- One ref as `for-each-ref` reports it.
local record RefEntry
  refname: string
  sha: string
end

--- One ref this push moves: `old` is the lease (the tip observed at
--- load, or "" for a ref that must not exist remotely yet); `delete`
--- pushes a deletion instead of the local ref's current value.
local record PushSpec
  ref: string
  old: string
  delete: boolean
end

--- List every ref under the given patterns, with its current object.
--- One process for however many patterns are given — `store.list`
--- passes `refs/heads/items` and `refs/heads/ended` together so the whole board
--- comes back from a single `for-each-ref`.
--- @param root string The repository root
--- @param patterns {string} Ref path prefixes, e.g. "refs/heads/items"
--- @return {RefEntry} | nil The refs found, possibly empty
--- @return string Error message
local function for_each_ref(root: string, patterns: {string}): {RefEntry} | nil, string
  local argv: {string} = {"git", "for-each-ref",
    "--format=%(refname) %(objectname)"}
  for _, p in ipairs(patterns) do
    argv[#argv + 1] = p
  end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git for-each-ref failed: %s"):format(r.stderr)
  end
  local out: {RefEntry} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    local refname, sha = line:match("^(%S+) (%S+)$")
    if refname then
      out[#out + 1] = {refname = refname, sha = sha}
    end
  end
  return out
end

--- One ref's committer date, as `%(committerdate:unix)` reports it.
--- @param root string The repository root
--- @param ref string The full ref name
--- @return integer | nil Epoch seconds
--- @return string Error message
local function committer_date_unix(root: string, ref: string): integer | nil, string
  local r, err = child.run({"git", "for-each-ref",
      "--format=%(committerdate:unix)", ref}, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git for-each-ref failed: %s"):format(r.stderr)
  end
  local t = math.tointeger(tonumber((r.stdout:gsub("%s+$", ""))))
  if t == nil then
    return nil, ("no such ref: %s"):format(ref)
  end
  return t
end

--- Move one ref, locally: a plain compare-and-swap against the value
--- this checkout last observed. `old` is `ZERO_SHA` for a ref that
--- must not exist yet — the shape a brand-new item's first commit
--- writes through.
--- @param root string The repository root
--- @param ref string The full ref name
--- @param new_sha string The ref's new value
--- @param old_sha string The value it must currently hold
--- @return boolean True on success
--- @return string Error message
local function update_ref(root: string, ref: string, new_sha: string,
    old_sha: string): boolean, string
  local r, err = child.run(
    {"git", "-c", "core.createObject=rename", "update-ref", ref, new_sha, old_sha},
    {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git update-ref failed: %s"):format(r.stderr)
  end
  return true
end

--- One item's ended-ref move: `refs/heads/items/<id>` becomes
--- `refs/heads/ended/<id>`, both at `sha` — the value fast-import (or
--- whatever wrote the item's new commit) already left at
--- `refs/heads/items/<id>`, so it is also the delete's own compare value,
--- not the tip observed before that write.
local record EndedMove
  id: string
  sha: string
end

--- Move every ended item in `moves` from `refs/heads/items/<id>` to
--- `refs/heads/ended/<id>` in ONE local transaction, regardless of how many
--- — every create and every delete either all land or none does, so
--- an interrupted move never leaves an item in both places or
--- neither, and a batch of several never costs more than one process.
--- @param root string The repository root
--- @param moves {EndedMove} The items ending in this save, possibly empty
--- @return boolean True on success (including an empty `moves`)
--- @return string Error message
local function move_many_to_ended(root: string, moves: {EndedMove}): boolean, string
  if #moves == 0 then
    return true
  end
  local lines: {string} = {}
  for _, m in ipairs(moves) do
    lines[#lines + 1] = ("create refs/heads/ended/%s %s\n"):format(m.id, m.sha)
    lines[#lines + 1] = ("delete refs/heads/items/%s %s\n"):format(m.id, m.sha)
  end
  local r, err = child.run(
    {"git", "-c", "core.createObject=rename", "update-ref", "--stdin"},
    {cwd = root, stdin = table.concat(lines)})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git update-ref --stdin failed: %s"):format(r.stderr)
  end
  return true
end

--- Push every ref a save touched in one atomic, leased push. Each
--- spec's `old` is the tip this checkout observed (or "" for a ref
--- that must not exist on the remote yet) — the compare-and-swap that
--- makes a lost race detectable instead of silently overwritten.
--- `push.negotiate=false` is set because a `file://` remote's ACK/NAK
--- negotiation otherwise logs protocol noise on stderr that would
--- otherwise be mistaken for a real refusal.
--- @param root string The repository root
--- @param specs {PushSpec} The refs to push together
--- @return boolean True once every ref landed
--- @return boolean True when the rejection names a lost race (stale
--- lease); meaningless when the push succeeded
--- @return string Error message; git's own text on a real rejection
local function push_atomic(root: string, specs: {PushSpec}): boolean, boolean, string
  local argv: {string} = {"git", "-c", "push.negotiate=false", "-c",
    "core.createObject=rename", "push", "--atomic"}
  for _, spec in ipairs(specs) do
    argv[#argv + 1] = ("--force-with-lease=%s:%s"):format(spec.ref, spec.old)
  end
  argv[#argv + 1] = "origin"
  for _, spec in ipairs(specs) do
    if spec.delete then
      argv[#argv + 1] = ":" .. spec.ref
    else
      argv[#argv + 1] = spec.ref
    end
  end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return false, false, err
  end
  if r.ok then
    return true, false, ""
  end
  -- A lease failure prints `! [rejected] <ref> -> <ref> (stale info)`;
  -- a policy refusal (a pre-receive hook, a protected ref) prints
  -- `! [remote rejected] ... (<the hook's own reason>)` instead — a
  -- DIFFERENT bracket text that must never read as a race. Matching
  -- "(stale info)" alone would miss a lease loss git reports some
  -- other way (a fetch is stale too, say), so both markers are
  -- checked, but "rejected" alone is not: it is a substring of
  -- "remote rejected" as much as of "[rejected]".
  local detail = (r.stderr or ""):gsub("%s+$", "")
  local stale = detail:find("stale info", 1, true) ~= nil
  or detail:find("! [rejected]", 1, true) ~= nil
  return false, stale, detail
end

--- Fetch the remote's refs, pruning any local ref it no longer holds:
--- the whole lost-race recovery, given the mirror refspecs
--- `store.init_repo` writes to `remote.origin.fetch`.
--- @param root string The repository root
--- @return boolean True on success
--- @return string Error message
local function fetch_prune(root: string): boolean, string
  local r, err = child.run({"git", "-c", "push.negotiate=false",
      "fetch", "-q", "--prune", "origin"}, {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git fetch failed: %s"):format(r.stderr)
  end
  return true
end

local record refs
  ZERO_SHA: string
  type RefEntry = RefEntry
  type PushSpec = PushSpec
  type EndedMove = EndedMove
  for_each_ref: function(root: string, patterns: {string}): {RefEntry} | nil, string
  committer_date_unix: function(root: string, ref: string): integer | nil, string
  update_ref: function(root: string, ref: string, new_sha: string,
  old_sha: string): boolean, string
  move_many_to_ended: function(root: string, moves: {EndedMove}): boolean, string
  push_atomic: function(root: string, specs: {PushSpec}): boolean, boolean, string
  fetch_prune: function(root: string): boolean, string
end

local M: refs = {
  ZERO_SHA = ZERO_SHA,
  for_each_ref = for_each_ref,
  committer_date_unix = committer_date_unix,
  update_ref = update_ref,
  move_many_to_ended = move_many_to_ended,
  push_atomic = push_atomic,
  fetch_prune = fetch_prune,
}

return M
