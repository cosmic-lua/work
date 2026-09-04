--- Ref plumbing: reading `refs/heads/items/*`, `refs/heads/ended/*` and
--- `refs/heads/board/*` with `for-each-ref`, moving one ref with
--- `update-ref` (a single compare-and-swap), telling whether one
--- commit descends from another (`is_ancestor` — how a reader picks a
--- winner when one id ends up filed under both namespaces), and
--- pushing every ref one save touched in a single atomic, leased
--- push. `_work.gitobj` is the object half; this is the naming half,
--- and `_work.store` is the only caller outside tests.
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
--- load, or "" for a ref that must not exist remotely yet). The
--- pushing credential can create and update a branch but never
--- delete one, so nothing here ever asks for a deletion.
local record PushSpec
  ref: string
  old: string
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

--- Whether `ancestor` is an ancestor of (or equal to) `descendant` —
--- `git merge-base --is-ancestor`. Exists so a reader can tell which
--- of two refs for the same id (one under `refs/heads/items`, one
--- under `refs/heads/ended` — the residue of a resolution whose
--- atomic push landed the create half of a namespace move but lost
--- the delete half, since the pushing credential can create and
--- update a branch but never delete one) is the live one: the ref
--- whose commit descends from the other's is still moving forward,
--- the other is the stale half of that half-landed push. A clean "no"
--- (exit 1) and a real git failure both come back false — a caller
--- picking between two refs treats "not proven to descend" the same
--- way regardless of which one it was, so nothing here needs a third
--- state.
--- @param root string The repository root
--- @param ancestor string Commit sha
--- @param descendant string Commit sha
--- @return boolean True only when the check ran and answered yes
local function is_ancestor(root: string, ancestor: string, descendant: string): boolean
  local r = child.run({"git", "merge-base", "--is-ancestor", ancestor, descendant},
    {cwd = root})
  return r ~= nil and r.ok
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
    argv[#argv + 1] = spec.ref
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

--- The three mirror refspecs every clone of the board repository
--- fetches with, so a `fetch --prune` is the whole lost-race recovery.
local FETCH_REFSPECS < const >: {string} = {
  "+refs/heads/items/*:refs/heads/items/*",
  "+refs/heads/ended/*:refs/heads/ended/*",
  "+refs/heads/board/*:refs/heads/board/*",
}

--- Add the mirror refspecs to `remote.origin.fetch` when the clone has
--- an `origin` that lacks them. A plain `git clone` fetches only the
--- checked-out branch's refs, so a fresh clone that runs `sync` before
--- any `init` needs this to see the board at all. Existing refspecs are
--- never replaced, so a `git pull` on the branch keeps working; a
--- repository without `origin` needs nothing.
--- @param root string The repository root
--- @return boolean True once the refspecs are present
--- @return string Error message
local function ensure_refspecs(root: string): boolean, string
  local has_origin = child.run({"git", "remote"}, {cwd = root})
  if has_origin == nil or not has_origin.ok
  or has_origin.stdout:find("origin", 1, true) == nil then
    return true
  end
  local current = child.run({"git", "config", "--get-all", "remote.origin.fetch"},
    {cwd = root})
  local have = (current ~= nil and current.ok) and current.stdout or ""
  for _, spec in ipairs(FETCH_REFSPECS) do
    if have:find(spec, 1, true) == nil then
      local added = child.run({"git", "config", "--add", "remote.origin.fetch", spec},
        {cwd = root})
      if added == nil or not added.ok then
        return false, ("could not set remote.origin.fetch %s"):format(spec)
      end
    end
  end
  return true
end

local record refs
  ZERO_SHA: string
  ensure_refspecs: function(root: string): boolean, string
  type RefEntry = RefEntry
  type PushSpec = PushSpec
  for_each_ref: function(root: string, patterns: {string}): {RefEntry} | nil, string
  committer_date_unix: function(root: string, ref: string): integer | nil, string
  update_ref: function(root: string, ref: string, new_sha: string,
  old_sha: string): boolean, string
  is_ancestor: function(root: string, ancestor: string, descendant: string): boolean
  push_atomic: function(root: string, specs: {PushSpec}): boolean, boolean, string
  fetch_prune: function(root: string): boolean, string
end

local M: refs = {
  ZERO_SHA = ZERO_SHA,
  ensure_refspecs = ensure_refspecs,
  for_each_ref = for_each_ref,
  committer_date_unix = committer_date_unix,
  update_ref = update_ref,
  is_ancestor = is_ancestor,
  push_atomic = push_atomic,
  fetch_prune = fetch_prune,
}

return M
