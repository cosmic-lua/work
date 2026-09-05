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
local fd = require("cosmic.fd")
local hash = require("cosmic.hash")

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

--- One `git cat-file --batch` process, answering one round of queries at a time — one process for a caller's several DEPENDENT rounds.
local record BatchSession
  _handle: child.Handle
  _writer: fd.Handle
  _buf: string
  _closed: boolean
  --- One round: blocks until every query has its answer, a missing object included, without crossing into a later round's bytes.
  --- @param queries {string} Rev specs to read, may be empty
  --- @return {string: BatchEntry} | nil One entry per query git could resolve
  --- @return string Error message
  request: function(self: BatchSession, queries: {string}): {string: BatchEntry} | nil, string
  --- Send stdin EOF and reap the process; idempotent, even after a failed `request`.
  --- @return boolean
  --- @return string Error message
  close: function(self: BatchSession): boolean, string
end

--- Attach BatchSession's methods to an already-started process and its stdin pipe's writer end.
--- @param handle child.Handle The started `git cat-file --batch`
--- @param writer fd.Handle This session's own end of its stdin pipe
--- @return BatchSession
local function make_session(handle: child.Handle, writer: fd.Handle): BatchSession
  local sess: BatchSession = {_handle = handle, _writer = writer, _buf = "", _closed = false}

  function sess:request(queries: {string}): {string: BatchEntry} | nil, string
    if #queries == 0 then
      return {}
    end
    local out: {string: BatchEntry} = {}
    for _, query in ipairs(queries) do
      -- One query, then its full answer, before the next query —
      -- never the whole round up front, or a large round can fill
      -- both pipes (its unread output, our unwritten queries) with
      -- neither side draining.
      local line = query .. "\n"
      local off = 0
      while off < #line do
        local n, werr = self._writer:write(line:sub(off + 1))
        if n == nil then
          return nil, werr
        end
        off = off + n
      end
      while true do
        local nl = self._buf:find("\n", 1, true)
        if nl ~= nil then
          local header = self._buf:sub(1, nl - 1)
          if header:match(" missing$") then
            self._buf = self._buf:sub(nl + 1)
            break
          end
          local otype, size_s = header:match("^%S+ (%S+) (%d+)$")
          if otype == nil then
            return nil, ("cat-file --batch: unparseable header: %s"):format(header)
          end
          local size = math.tointeger(tonumber(size_s))
          if #self._buf >= nl + size + 1 then
            out[query] = {otype = otype, size = size, content = self._buf:sub(nl + 1, nl + size)}
            self._buf = self._buf:sub(nl + size + 2) -- past the object's own trailing "\n"
            break
          end
        end
        local chunk, rerr = self._handle:read()
        if chunk == nil then
          return nil, rerr or "cat-file --batch: unexpected eof"
        end
        self._buf = self._buf .. chunk
      end
    end
    return out
  end

  function sess:close(): boolean, string
    if self._closed then
      return true
    end
    self._closed = true
    local _wok, _werr = self._writer:close()
    local _r, werr = self._handle:wait()
    if werr ~= nil then
      return false, werr
    end
    return true
  end

  return sess
end

--- Start one `git cat-file --batch` process for several dependent
--- rounds (`request`), closed by the caller when done (`close`).
--- @param root string The repository root
--- @return BatchSession | nil
--- @return string Error message
local function batch_session(root: string): BatchSession | nil, string
  -- CLOEXEC, or the child's un-dup'd writer copy survives into git and
  -- keeps the pipe open, so closing OUR writer never reaches EOF.
  local p, perr = fd.pipe(fd.O_CLOEXEC)
  if p == nil then
    return nil, perr
  end
  local h, herr = child.start({"git", "cat-file", "--batch"}, {cwd = root, stdin = p.reader})
  if h == nil then
    local _ok, _err = p:close()
    return nil, herr
  end
  -- The child holds its own dup2'd copy; only this session's writer decides EOF.
  local _rok, _rerr = p.reader:close()
  return make_session(h, p.writer)
end

--- Close a session and forward a round's failure, so an early return never leaves the process running.
--- @param sess BatchSession The session to close
--- @param err string The error to forward
--- @return nil
--- @return string The same error
local function session_fail(sess: BatchSession, err: string): nil, string
  local _ok, _err = sess:close()
  return nil, err
end

--- Read a batch of objects in one `git cat-file --batch` process — the
--- one-shot form of `BatchSession`, for a single round; a caller with
--- several dependent rounds wants `batch_session` directly. A missing
--- path or object is simply absent from the result.
--- @param root string The repository root
--- @param queries {string} Rev specs to read, may be empty
--- @return {string: BatchEntry} | nil One entry per query git could resolve
--- @return string Error message
local function cat_file_batch(root: string,
    queries: {string}): {string: BatchEntry} | nil, string
  if #queries == 0 then
    return {}
  end
  local sess, serr = batch_session(root)
  if sess == nil then
    return nil, serr
  end
  local out, oerr = sess:request(queries)
  if out == nil then
    return session_fail(sess, oerr)
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
  type BatchSession = BatchSession
  type CommitSpec = CommitSpec
  hash_object: function(root: string, content: string): string | nil, string
  hash_object_write: function(root: string, content: string): string | nil, string
  tree_of: function(root: string, commit_sha: string): string | nil, string
  tree_of_batch: function(root: string,
  commit_shas: {string}): {string: string} | nil, string
  mktree: function(root: string, entries: {TreeEntry}): string | nil, string
  mktree_write: function(root: string, entries: {TreeEntry}): string | nil, string
  commit_tree: function(root: string, spec: CommitSpec): string | nil, string
  batch_session: function(root: string): BatchSession | nil, string
  session_fail: function(sess: BatchSession, err: string): nil, string
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
  batch_session = batch_session,
  session_fail = session_fail,
  cat_file_batch = cat_file_batch,
  parse_tree = parse_tree,
}

return M
