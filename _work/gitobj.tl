--- Low-level git object plumbing: writing blobs and trees, building
--- commits with independent author/committer identities and an `Op:`
--- trailer, batch-reading blob and raw tree content in as few
--- processes as possible, and parsing a raw tree object's bytes back
--- into entries. Every store operation that touches git objects (as
--- opposed to refs, `_work.refs`) goes through here, so the exact
--- argv shapes stay in one place.
local child = require("cosmic.child")
local codec = require("cosmic.codec")
local env = require("cosmic.env")

--- The sha1 of the empty blob, the same object `git hash-object` gives
--- an empty string — used for `beats/<id>` markers, which carry no
--- content of their own.
local EMPTY_BLOB_SHA < const > = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"

--- One entry in a tree being built or read back.
local record TreeEntry
  --- "100644" for a blob, "40000" for a subtree — git's own raw-mode
  --- spelling, which drops the leading zero a tree carries.
  mode: string
  otype: string -- "blob" | "tree"
  sha: string -- 40 lowercase hex
  name: string
end

--- One object `cat_file_batch` read back.
local record BatchEntry
  otype: string -- "blob" | "tree" | "commit"
  size: integer
  content: string
end

--- Write one blob and return its sha. A handful of these per save, so
--- one process each is the deliberate cost `git hash-object -w` pays
--- for landing the object straight in the odb.
--- @param root string The repository root
--- @param content string The blob's bytes
--- @return string | nil The blob's sha
--- @return string Error message
local function hash_object(root: string, content: string): string | nil, string
  local r, err = child.run({"git", "-c", "core.createObject=rename",
      "hash-object", "-w", "--stdin"}, {cwd = root, stdin = content})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git hash-object failed: %s"):format(r.stderr)
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- The tree a commit points at.
--- @param root string The repository root
--- @param commit_sha string The commit's sha
--- @return string | nil The commit's tree sha
--- @return string Error message
local function tree_of(root: string, commit_sha: string): string | nil, string
  local r, err = child.run({"git", "rev-parse", commit_sha .. "^{tree}"}, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git rev-parse failed: %s"):format(r.stderr)
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- Build one tree from its entries and return its sha. `git mktree`
--- sorts the entries itself, so callers never have to; zero entries
--- is legal and gives back the well-known empty tree, which a bounded
--- mutation's `refs/board/seq` marker commit is built on.
--- @param root string The repository root
--- @param entries {TreeEntry} The tree's entries, possibly empty
--- @return string | nil The tree's sha
--- @return string Error message
local function mktree(root: string, entries: {TreeEntry}): string | nil, string
  local lines: {string} = {}
  for _, e in ipairs(entries) do
    lines[#lines + 1] = ("%s %s %s\t%s\n"):format(e.mode, e.otype, e.sha, e.name)
  end
  local r, err = child.run({"git", "mktree"},
    {cwd = root, stdin = table.concat(lines)})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git mktree failed: %s"):format(r.stderr)
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- One commit to build: a tree, its parents (empty for a brand-new
--- item's first commit), the identities on both sides, and the verb
--- that made it — recorded as the one `Op:` trailer every commit here
--- carries.
local record CommitSpec
  tree: string
  parents: {string}
  message: string
  author_name: string
  author_email: string
  --- "<epoch> <+off>", e.g. "1700000000 +0000"; nil uses the current time.
  author_date: string
  committer_name: string
  committer_email: string
  committer_date: string
  op: string
end

--- Build one commit object and return its sha. Author and committer
--- are independent identities — the session that made the change on
--- one side, the fixed tool identity on the other — carried through
--- `GIT_AUTHOR_*`/`GIT_COMMITTER_*` rather than `-c user.*`, which
--- cannot express two different identities in one call.
--- @param root string The repository root
--- @param spec CommitSpec The commit to build
--- @return string | nil The commit's sha
--- @return string Error message
local function commit_tree(root: string, spec: CommitSpec): string | nil, string
  local argv: {string} = {"git", "commit-tree", spec.tree}
  for _, p in ipairs(spec.parents or {}) do
    argv[#argv + 1] = "-p"
    argv[#argv + 1] = p
  end
  local message = spec.message
  if (spec.op or "") ~= "" then
    message = message .. "\n\nOp: " .. spec.op
  end
  argv[#argv + 1] = "-m"
  argv[#argv + 1] = message
  local set: {string: string} = {
    GIT_AUTHOR_NAME = spec.author_name,
    GIT_AUTHOR_EMAIL = spec.author_email,
    GIT_COMMITTER_NAME = spec.committer_name,
    GIT_COMMITTER_EMAIL = spec.committer_email,
  }
  if (spec.author_date or "") ~= "" then
    set.GIT_AUTHOR_DATE = spec.author_date
  end
  if (spec.committer_date or "") ~= "" then
    set.GIT_COMMITTER_DATE = spec.committer_date
  end
  local r, err = child.run({"git", "-c", "core.createObject=rename",
      table.unpack(argv, 2)},
    {cwd = root, env = env.list({set = set})})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git commit-tree failed: %s"):format(r.stderr)
  end
  return (r.stdout:gsub("%s+$", ""))
end

--- Read a batch of objects in one `git cat-file --batch` process.
--- Each query is a git rev spec: `<ref>:meta`, `<sha>:blocked_by/<id>`,
--- a bare sha, and so on. Content is read by exact byte count, so
--- binary content (a raw tree object) round-trips intact; a missing
--- path or object is simply absent from the result rather than an
--- error, matching git's own `<query> missing` answer.
--- @param root string The repository root
--- @param queries {string} Rev specs to read, may be empty
--- @return {string: BatchEntry} | nil One entry per query git could resolve
--- @return string Error message
local function cat_file_batch(root: string,
    queries: {string}): {string: BatchEntry} | nil, string
  if #queries == 0 then
    return {}
  end
  local r, err = child.run({"git", "cat-file", "--batch"},
    {cwd = root, stdin = table.concat(queries, "\n") .. "\n"})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git cat-file --batch failed: %s"):format(r.stderr)
  end
  -- Responses come back one per query, in the SAME order as stdin —
  -- that ordering, not the header text, is what ties a result back to
  -- the query string that produced it, so a caller can ask the same
  -- rev spec twice (two items sharing a blocker's reason blob) and
  -- get two independent entries.
  local out: {string: BatchEntry} = {}
  local buf = r.stdout
  local pos = 1
  for _, query in ipairs(queries) do
    local nl = buf:find("\n", pos, true)
    if nl == nil then
      return nil, ("cat-file --batch: truncated output after %d bytes"):format(pos - 1)
    end
    local header = buf:sub(pos, nl - 1)
    if header:match(" missing$") then
      pos = nl + 1
    else
      local otype, size_s = header:match("^%S+ (%S+) (%d+)$")
      if otype == nil then
        return nil, ("cat-file --batch: unparseable header: %s"):format(header)
      end
      local size = math.tointeger(tonumber(size_s))
      local content_start = nl + 1
      local content_end = content_start + size - 1
      out[query] = {otype = otype, size = size, content = buf:sub(content_start, content_end)}
      pos = content_end + 2 -- skip the object's own trailing "\n"
    end
  end
  return out, ""
end

--- Bytes to lowercase hex.
--- @param raw string Raw bytes
--- @return string Hex text, twice as long
local function to_hex(raw: string): string
  return codec.encode_hex(raw)
end

--- Parse a raw tree object's bytes into its entries: repeated
--- `<mode> <name>\0<20 raw sha bytes>`, exactly what `cat_file_batch`
--- hands back for a `tree` query.
--- @param raw string The raw tree object bytes
--- @return {TreeEntry} The entries, in the order the tree carries them
local function parse_tree(raw: string): {TreeEntry}
  local out: {TreeEntry} = {}
  local i = 1
  local n = #raw
  while i <= n do
    local sp = raw:find(" ", i, true)
    local mode = raw:sub(i, sp - 1)
    local nul = raw:find("\0", sp + 1, true)
    local name = raw:sub(sp + 1, nul - 1)
    local sha_bytes = raw:sub(nul + 1, nul + 20)
    local otype = "blob"
    if mode == "40000" then
      otype = "tree"
    end
    out[#out + 1] = {mode = mode, otype = otype, sha = to_hex(sha_bytes), name = name}
    i = nul + 21
  end
  return out
end

local record gitobj
  EMPTY_BLOB_SHA: string
  type TreeEntry = TreeEntry
  type BatchEntry = BatchEntry
  type CommitSpec = CommitSpec
  hash_object: function(root: string, content: string): string | nil, string
  tree_of: function(root: string, commit_sha: string): string | nil, string
  mktree: function(root: string, entries: {TreeEntry}): string | nil, string
  commit_tree: function(root: string, spec: CommitSpec): string | nil, string
  cat_file_batch: function(root: string,
  queries: {string}): {string: BatchEntry} | nil, string
  parse_tree: function(raw: string): {TreeEntry}
end

local M: gitobj = {
  EMPTY_BLOB_SHA = EMPTY_BLOB_SHA,
  hash_object = hash_object,
  tree_of = tree_of,
  mktree = mktree,
  commit_tree = commit_tree,
  cat_file_batch = cat_file_batch,
  parse_tree = parse_tree,
}

return M
