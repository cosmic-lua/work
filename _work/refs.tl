--- Canonical ref naming, local compare-and-swap, ancestry, and atomic leased
--- publication. `_work.gitobj` owns Git objects; this module owns ref identity.
local child = require("cosmic.child")

--- The sha `update-ref`/`--force-with-lease` treat as "does not exist
--- yet" — a brand-new ref's lease value.
local ZERO_SHA < const > = ("0"):rep(40)

--- One ref as `for-each-ref` reports it.
local record RefEntry
  refname: string
  sha: string
  touched: integer
end

--- One ref this push moves; `old` is its observed lease.
local record PushSpec
  ref: string
  old: string
end

--- One compare-and-swap in a prepared board transaction.
local record RefUpdate
  ref: string
  expected: string
  next: string
end

--- The two deliberately distinct board modes. Remote-backed boards
--- read confirmed state only from remote-tracking refs. Local boards
--- are an explicit simulation/testing mode and read local heads.
local enum BoardMode
  "local"
  "remote"
end

-- Mode is repository configuration, not per-read state. Canonical reads call
-- this helper several times in one operation; cache the answer by root so the
-- transport boundary does not add a `git config` process to every ref lookup.
local MODE_BY_ROOT: {string: BoardMode} = {}
local REMOTE_BY_ROOT: {string: string} = {}

--- The caller-selected Git remote whose tracking namespace is canonical for a
--- remote-backed board. `origin` is only the compatibility default; it is not
--- baked into any canonical ref mapping.
local function board_remote(root: string): string
  local known = REMOTE_BY_ROOT[root]
  if known ~= nil then return known end
  local configured = child.run({"git", "config", "--get", "gitboard.remote"},
    {cwd = root})
  if configured ~= nil and configured.ok then
    local value = configured.stdout:gsub("%s+$", "")
    if value ~= "" then
      REMOTE_BY_ROOT[root] = value
      return value
    end
  end
  REMOTE_BY_ROOT[root] = "origin"
  return "origin"
end

--- Select a remote for this invocation without performing I/O or rewriting
--- repository configuration. CLI `--remote NAME` uses this before opening the
--- store so ID resolution and later transport inspect the same namespace.
local function use_remote(root: string, remote: string): boolean, string
  if remote == "" or remote:match("^[%w._/-]+$") == nil
  or remote:find("..", 1, true) ~= nil or remote:sub(1, 1) == "/"
  or remote:sub(-1) == "/" then
    return false, "remote name is not safe in a remote-tracking ref"
  end
  REMOTE_BY_ROOT[root] = remote
  return true, ""
end

--- Persist the canonical remote in checkout-local Git configuration.
local function set_board_remote(root: string, remote: string): boolean, string
  local valid, verr = use_remote(root, remote)
  if not valid then return false, verr end
  local r, err = child.run({"git", "config", "gitboard.remote", remote},
    {cwd = root})
  if r == nil then return false, err end
  if not r.ok then
    return false, ("git config gitboard.remote failed: %s"):format(r.stderr)
  end
  return true, ""
end

--- Read the board mode from repository-local configuration. Older
--- repositories without the marker retain the historical inference
--- for migration only; `store.init_repo` writes the explicit value.
--- This performs local configuration reads only, never remote I/O.
local function board_mode(root: string): BoardMode
  local known = MODE_BY_ROOT[root]
  if known ~= nil then
    return known
  end
  local configured = child.run({"git", "config", "--get", "gitboard.mode"},
    {cwd = root})
  if configured ~= nil and configured.ok then
    local value = configured.stdout:gsub("%s+$", "")
    if value == "remote" then
      MODE_BY_ROOT[root] = "remote"
      return "remote"
    end
    if value == "local" then
      MODE_BY_ROOT[root] = "local"
      return "local"
    end
  end
  local remotes = child.run({"git", "remote"}, {cwd = root})
  if remotes ~= nil and remotes.ok and remotes.stdout:match("%S") ~= nil then
    MODE_BY_ROOT[root] = "remote"
    return "remote"
  end
  MODE_BY_ROOT[root] = "local"
  return "local"
end

--- Persist an explicit board mode. This changes only `.git/config`.
local function set_board_mode(root: string, mode: BoardMode): boolean, string
  if mode ~= "local" and mode ~= "remote" then
    return false, "board mode must be local or remote"
  end
  local r, err = child.run({"git", "config", "gitboard.mode", mode}, {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git config gitboard.mode failed: %s"):format(r.stderr)
  end
  MODE_BY_ROOT[root] = mode
  return true, ""
end

--- Map a publish target to the fetched ref that confirms it. The
--- caller fetches `refs/heads/items/*` to
--- `refs/remotes/<remote>/items/*` (and likewise for ended/board);
--- gitboard itself never fetches.
local function tracking_ref(target: string, remote?: string): string | nil, string
  local tail = target:match("^refs/heads/(items/.+)$")
  or target:match("^refs/heads/(ended/.+)$")
  or target:match("^refs/heads/(board/.+)$")
  if tail == nil then
    return nil, ("not a board ref: %s"):format(target)
  end
  return ("refs/remotes/%s/%s"):format(remote or "origin", tail)
end

--- The ref a board reads as confirmed state in its configured mode.
local function canonical_ref(root: string, target: string,
    remote?: string): string | nil, string
  if board_mode(root) == "local" then
    return target
  end
  return tracking_ref(target, remote or board_remote(root))
end

--- Read exactly one ref without accepting prefix matches.
local function read_ref(root: string, ref: string): string | nil, string
  local r, err = child.run({"git", "rev-parse", "--verify", "--quiet", ref},
    {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return ZERO_SHA, ""
  end
  return (r.stdout:gsub("%s+$", "")), ""
end

--- Apply a set of local ref CAS operations as one `update-ref`
--- transaction. This is used only to promote local-only boards and to
--- clean staging refs. Durable remote publication remains caller-owned
--- and MUST use atomic leased transport.
local function update_refs_atomic(root: string,
    updates: {RefUpdate}): boolean, string
  if #updates == 0 then
    return true, ""
  end
  local lines: {string} = {"start\n"}
  for _, u in ipairs(updates) do
    if u.next == ZERO_SHA then
      lines[#lines + 1] = ("delete %s %s\n"):format(u.ref, u.expected)
    else
      lines[#lines + 1] = ("update %s %s %s\n"):format(u.ref, u.next, u.expected)
    end
  end
  lines[#lines + 1] = "prepare\ncommit\n"
  local r, err = child.run({"git", "-c", "core.createObject=rename",
      "update-ref", "--stdin"}, {cwd = root, stdin = table.concat(lines)})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git update-ref transaction refused: %s"):format(r.stderr)
  end
  return true, ""
end

--- List every ref under the given patterns, with its current object and
--- committer date. One process for however many patterns are given —
--- `store.list` passes `refs/heads/items` and `refs/heads/ended`
--- together so the whole board comes back from a single
--- `for-each-ref` — and the committer date rides along in the same
--- pass, so a caller that already takes this snapshot never needs a
--- second process per ref to learn when it was last touched
--- (`_work.publish.touched_at`).
--- @param root string The repository root
--- @param patterns {string} Ref path prefixes, e.g. "refs/heads/items"
--- @return {RefEntry} | nil The refs found, possibly empty
--- @return string Error message
local function for_each_ref_raw(root: string,
    patterns: {string}): {RefEntry} | nil, string
  local argv: {string} = {"git", "for-each-ref",
    "--format=%(refname) %(objectname) %(committerdate:unix)"}
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
    local refname, sha, touched = line:match("^(%S+) (%S+) (%S+)$")
    if refname then
      out[#out + 1] = {refname = refname, sha = sha,
        touched = math.tointeger(tonumber(touched)) or 0}
    end
  end
  return out
end

--- List confirmed board refs. Remote-backed repositories translate
--- the familiar target namespace to the configured remote's tracking refs, then
--- translate result names back to targets so the rest of the board
--- model remains transport-neutral. Staging/write plumbing that needs
--- literal refs uses `for_each_ref_raw` instead.
local function for_each_ref(root: string,
    patterns: {string}): {RefEntry} | nil, string
  if board_mode(root) == "local" then
    return for_each_ref_raw(root, patterns)
  end
  local mapped: {string} = {}
  local remote = board_remote(root)
  for _, p in ipairs(patterns) do
    local tail = p:match("^refs/heads/(items.*)$")
    or p:match("^refs/heads/(ended.*)$")
    or p:match("^refs/heads/(board.*)$")
    mapped[#mapped + 1] = tail and ("refs/remotes/" .. remote .. "/" .. tail) or p
  end
  local found, err = for_each_ref_raw(root, mapped)
  if found == nil then
    return nil, err
  end
  for _, e in ipairs(found) do
    local quoted = remote:gsub("([^%w])", "%%%1")
    local tail = e.refname:match("^refs/remotes/" .. quoted .. "/(items/.+)$")
    or e.refname:match("^refs/remotes/" .. quoted .. "/(ended/.+)$")
    or e.refname:match("^refs/remotes/" .. quoted .. "/(board/.+)$")
    if tail ~= nil then
      e.refname = "refs/heads/" .. tail
    end
  end
  return found, ""
end

--- One ref's committer date, as `%(committerdate:unix)` reports it.
--- @param root string The repository root
--- @param ref string The full ref name
--- @return integer | nil Epoch seconds
--- @return string Error message
local function committer_date_unix(root: string, ref: string): integer | nil, string
  local canonical, cerr = canonical_ref(root, ref)
  if canonical == nil then
    return nil, cerr
  end
  local r, err = child.run({"git", "for-each-ref",
      "--format=%(committerdate:unix)", canonical}, {cwd = root})
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
  argv[#argv + 1] = board_remote(root)
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

--- Fetch the configured board remote's refs, pruning any local ref it no
--- longer holds. This compatibility helper still performs I/O; new CLI paths
--- render equivalent caller-owned transport through `_work.gittransport`.
--- @param root string The repository root
--- @return boolean True on success
--- @return string Error message
local function fetch_prune(root: string): boolean, string
  local r, err = child.run({"git", "-c", "push.negotiate=false",
      "fetch", "-q", "--prune", board_remote(root)}, {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    return false, ("git fetch failed: %s"):format(r.stderr)
  end
  return true
end

--- The three mirror refspecs for a configured board remote.
local function fetch_refspecs(remote: string): {string}
  return {
    ("+refs/heads/items/*:refs/remotes/%s/items/*"):format(remote),
    ("+refs/heads/ended/*:refs/remotes/%s/ended/*"):format(remote),
    ("+refs/heads/board/*:refs/remotes/%s/board/*"):format(remote),
  }
end

--- Add the remote-tracking refspecs to the configured board remote when the
--- clone has that remote. A plain `git clone` fetches only the
--- checked-out branch's refs, so a fresh clone that runs `sync` before
--- any `init` needs this to see the board at all. Existing refspecs are
--- never replaced, so a `git pull` on the branch keeps working; a
--- repository without the configured remote needs nothing.
--- @param root string The repository root
--- @return boolean True once the refspecs are present
--- @return string Error message
local function ensure_refspecs(root: string): boolean, string
  local remote = board_remote(root)
  local has_remote = child.run({"git", "remote"}, {cwd = root})
  if has_remote == nil or not has_remote.ok then
    return true
  end
  local found = false
  for name in (has_remote.stdout .. "\n"):gmatch("([^\n]+)\n") do
    if name == remote then found = true end
  end
  if not found then return true end
  local key = "remote." .. remote .. ".fetch"
  local current = child.run({"git", "config", "--get-all", key},
    {cwd = root})
  local have = (current ~= nil and current.ok) and current.stdout or ""
  for _, spec in ipairs(fetch_refspecs(remote)) do
    if have:find(spec, 1, true) == nil then
      local added = child.run({"git", "config", "--add", key, spec},
        {cwd = root})
      if added == nil or not added.ok then
        return false, ("could not set %s %s"):format(key, spec)
      end
    end
  end
  return true
end

local record refs
  ZERO_SHA: string
  type RefUpdate = RefUpdate
  type BoardMode = BoardMode
  board_mode: function(root: string): BoardMode
  set_board_mode: function(root: string, mode: BoardMode): boolean, string
  board_remote: function(root: string): string
  use_remote: function(root: string, remote: string): boolean, string
  set_board_remote: function(root: string, remote: string): boolean, string
  tracking_ref: function(target: string, remote?: string): string | nil, string
  canonical_ref: function(root: string, target: string,
  remote?: string): string | nil, string
  read_ref: function(root: string, ref: string): string | nil, string
  update_refs_atomic: function(root: string, updates: {RefUpdate}): boolean, string
  ensure_refspecs: function(root: string): boolean, string
  type RefEntry = RefEntry
  type PushSpec = PushSpec
  for_each_ref: function(root: string, patterns: {string}): {RefEntry} | nil, string
  for_each_ref_raw: function(root: string, patterns: {string}): {RefEntry} | nil, string
  committer_date_unix: function(root: string, ref: string): integer | nil, string
  update_ref: function(root: string, ref: string, new_sha: string,
  old_sha: string): boolean, string
  is_ancestor: function(root: string, ancestor: string, descendant: string): boolean
  push_atomic: function(root: string, specs: {PushSpec}): boolean, boolean, string
  fetch_prune: function(root: string): boolean, string
end

local M: refs = {
  ZERO_SHA = ZERO_SHA,
  board_mode = board_mode,
  set_board_mode = set_board_mode,
  board_remote = board_remote,
  use_remote = use_remote,
  set_board_remote = set_board_remote,
  tracking_ref = tracking_ref,
  canonical_ref = canonical_ref,
  read_ref = read_ref,
  update_refs_atomic = update_refs_atomic,
  ensure_refspecs = ensure_refspecs,
  for_each_ref = for_each_ref,
  for_each_ref_raw = for_each_ref_raw,
  committer_date_unix = committer_date_unix,
  update_ref = update_ref,
  is_ancestor = is_ancestor,
  push_atomic = push_atomic,
  fetch_prune = fetch_prune,
}

return M
