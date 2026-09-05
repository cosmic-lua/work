--- Low-level git object plumbing: computing blob and tree ids in Lua
--- (no process, nothing written — `hash_object`/`mktree`), writing
--- them for real when needed (`hash_object_write`/`mktree_write`),
--- building commits with independent author/committer identities and
--- an `Op:` trailer, batch-reading blob and tree content in as few
--- processes as possible, and parsing a raw tree's bytes into
--- entries. Every store operation touching git objects (never refs,
--- `_work.refs`) goes through here, keeping argv shapes in one place.
local child = require("cosmic.child")
local codec = require("cosmic.codec")
local env = require("cosmic.env")
local gitbatch = require("_work.gitbatch")
local hash = require("cosmic.hash")

--- The batch-entry and session machinery `cat_file_batch` wraps —
--- split out to `_work.gitbatch`, whose type this module re-exports as
--- its own for every existing caller.
local type BatchEntry = gitbatch.BatchEntry

--- The sha1 of the empty blob, the same object `git hash-object` gives
--- an empty string — used for a reason-less `edges/<kind>/<id>`
--- marker, which carries no content of its own.
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

--- The sha1 blob id for content, computed in Lua: no process spawned,
--- nothing written to the repository. Git hashes a blob as
--- `"blob " .. #content .. "\0" .. content`, so this gives back the
--- same id `git hash-object` (without `-w`) would print for the same
--- bytes — the default for every caller that only needs to know an
--- id, never to create one; `hash_object_write` below is the writing
--- form, for a caller that follows up with something (`commit_tree`,
--- a push) that needs the object to actually exist.
--- @param _root string Unused — kept so this is a drop-in for the
--- writing form's signature
--- @param content string The blob's bytes
--- @return string | nil The blob's sha
--- @return string Error message
local function hash_object(_root: string, content: string): string | nil, string
  return codec.encode_hex(hash.digest("sha1", ("blob %d\0"):format(#content) .. content))
end

--- Write one blob and return its sha, actually landing it in the
--- repository's object database — the process-spawning form. A
--- handful of these per save, so one process each is the deliberate
--- cost `git hash-object -w` pays for that; a caller that only needs
--- the id to compare against (an audit, never a write) wants the pure
--- `hash_object` above instead.
--- @param root string The repository root
--- @param content string The blob's bytes
--- @return string | nil The blob's sha
--- @return string Error message
local function hash_object_write(root: string, content: string): string | nil, string
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

--- The tree every commit in `commit_shas` points at, all in ONE
--- `git rev-parse` process — the batched form of `tree_of`, for a
--- caller (`_work.gitfsck`'s whole-board audit) that needs every
--- item's observed tree and would otherwise pay one process per item.
--- Duplicate shas cost nothing extra: the map has one entry per
--- distinct sha regardless of how many times it appears in the input.
--- @param root string The repository root
--- @param commit_shas {string} Commit shas, possibly with duplicates
--- @return {string: string} | nil Commit sha -> tree sha
--- @return string Error message
local function tree_of_batch(root: string,
    commit_shas: {string}): {string: string} | nil, string
  if #commit_shas == 0 then
    return {}
  end
  local argv: {string} = {"git", "rev-parse"}
  for _, sha in ipairs(commit_shas) do
    argv[#argv + 1] = sha .. "^{tree}"
  end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return nil, err
  end
  if not r.ok then
    return nil, ("git rev-parse failed: %s"):format(r.stderr)
  end
  local out: {string: string} = {}
  local i = 1
  for line in r.stdout:gmatch("([^\n]+)") do
    out[commit_shas[i]] = line
    i = i + 1
  end
  return out, ""
end

--- Byte-wise less-than, the raw comparator git's own tree order uses —
--- kept explicit rather than Lua's `<` (whose string comparison can be
--- locale-sensitive) so a tree's canonical id never depends on the
--- runtime's locale.
--- @param a string
--- @param b string
--- @return boolean True when a sorts before b
local function byte_lt(a: string, b: string): boolean
  local n = math.min(#a, #b)
  for i = 1, n do
    local ca, cb = a:byte(i), b:byte(i)
    if ca ~= cb then
      return ca < cb
    end
  end
  return #a < #b
end

--- The key git's own tree order sorts an entry's name by: the name
--- itself, except a subtree (mode "40000") sorts as though its name
--- carried a trailing "/" — so `edges` (a subtree) sorts AFTER
--- `edges.txt` and `edges-x` (plain blobs), never as a prefix of them.
--- @param mode string The entry's mode
--- @param name string The entry's name
--- @return string The sort key
local function tree_sort_key(mode: string, name: string): string
  if mode == "40000" then
    return name .. "/"
  end
  return name
end

--- The sha1 tree id for a set of entries, computed in Lua: no process
--- spawned, nothing written. Entries are sorted into git's own tree
--- order first — byte-wise on `tree_sort_key`, never Lua's `<` — so
--- callers never have to pre-sort, and the id is the same regardless
--- of the input order; zero entries gives back the well-known empty
--- tree, which git treats as always present without it ever being
--- written. `mktree_write` below is the writing form, for a caller
--- that follows up with something that needs the tree to actually
--- exist.
--- @param _root string Unused — kept so this is a drop-in for the
--- writing form's signature
--- @param entries {TreeEntry} The tree's entries, possibly empty
--- @return string | nil The tree's sha
--- @return string Error message
local function mktree(_root: string, entries: {TreeEntry}): string | nil, string
  local sorted: {TreeEntry} = {}
  for _, e in ipairs(entries) do
    sorted[#sorted + 1] = e
  end
  table.sort(sorted, function(a: TreeEntry, b: TreeEntry): boolean
      return byte_lt(tree_sort_key(a.mode, a.name), tree_sort_key(b.mode, b.name))
    end)
  local parts: {string} = {}
  for _, e in ipairs(sorted) do
    local raw, derr = codec.decode_hex(e.sha)
    if raw == nil then
      return nil, ("mktree: bad sha for %s: %s"):format(e.name, derr)
    end
    parts[#parts + 1] = ("%s %s\0"):format(e.mode, e.name) .. raw
  end
  local body = table.concat(parts)
  return codec.encode_hex(hash.digest("sha1", ("tree %d\0"):format(#body) .. body))
end

--- Build one tree from its entries and return its sha, actually
--- writing it into the repository's object database — the
--- process-spawning form. `git mktree` sorts the entries itself, so
--- callers never have to; a caller that only needs the id to compare
--- against (an audit, never a write) wants the pure `mktree` above
--- instead. Every entry's own object must already exist in the
--- repository (the well-known empty tree and empty blob excepted) —
--- `git mktree` refuses an entry it cannot resolve.
--- @param root string The repository root
--- @param entries {TreeEntry} The tree's entries, possibly empty
--- @return string | nil The tree's sha
--- @return string Error message
local function mktree_write(root: string, entries: {TreeEntry}): string | nil, string
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

--- Read a batch of objects in one `git cat-file --batch` process: the
--- one-shot form of `_work.gitbatch`'s session, for a caller with a
--- single round to ask — a caller with several dependent rounds
--- (`_work.gitread.load`/`.list`, `_work.gitreadmany.load_many`) wants
--- `gitbatch.batch_session` directly, to pay for one process rather
--- than one per round. A missing path or object is simply absent from
--- the result, matching git's own `<query> missing` answer.
--- @param root string The repository root
--- @param queries {string} Rev specs to read, may be empty
--- @return {string: BatchEntry} | nil One entry per query git could resolve
--- @return string Error message
local function cat_file_batch(root: string,
    queries: {string}): {string: BatchEntry} | nil, string
  if #queries == 0 then
    return {}
  end
  local sess, serr = gitbatch.batch_session(root)
  if sess == nil then
    return nil, serr
  end
  local out, oerr = sess:request(queries)
  if out == nil then
    return gitbatch.session_fail(sess, oerr)
  end
  local _cok, cerr = sess:close()
  if not _cok then
    return nil, cerr
  end
  return out
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
  hash_object_write: function(root: string, content: string): string | nil, string
  tree_of: function(root: string, commit_sha: string): string | nil, string
  tree_of_batch: function(root: string,
  commit_shas: {string}): {string: string} | nil, string
  mktree: function(root: string, entries: {TreeEntry}): string | nil, string
  mktree_write: function(root: string, entries: {TreeEntry}): string | nil, string
  commit_tree: function(root: string, spec: CommitSpec): string | nil, string
  cat_file_batch: function(root: string,
  queries: {string}): {string: BatchEntry} | nil, string
  parse_tree: function(raw: string): {TreeEntry}
end

local M: gitobj = {
  EMPTY_BLOB_SHA = EMPTY_BLOB_SHA,
  hash_object = hash_object,
  hash_object_write = hash_object_write,
  tree_of = tree_of,
  tree_of_batch = tree_of_batch,
  mktree = mktree,
  mktree_write = mktree_write,
  commit_tree = commit_tree,
  cat_file_batch = cat_file_batch,
  parse_tree = parse_tree,
}

return M
