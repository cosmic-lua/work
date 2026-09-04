--- The one-time move off the old layout: `items/<id>.tl` +
--- `items/<id>.md` files in a git directory, at a given revision,
--- become `refs/items/<id>`/`refs/ended/<id>` refs in the CURRENT
--- store — with every commit that ever touched an item replayed, in
--- order, under the original author date and the session its subject
--- named, so `gitboard show <id>` and `git log` on its ref read
--- exactly as they would have if the ref had existed from the start.
--- This is also how the tests build fixture history: a small git
--- directory in the old layout, imported into a scratch store.
local child = require("cosmic.child")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local literal = require("cosmic.literal")
local product = require("_work.product")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")

--- The tool's own git identity — the committer on every replayed
--- commit, and the author too when a subject names no session.
local TOOL_NAME < const > = "Claude"
local TOOL_EMAIL < const > = "noreply@anthropic.com"

--- One historical commit that touched an item's pair of files.
local record Commit
  sha: string
  at: integer
  subject: string
end

--- Every `<id>` an `items/<id>.tl` file names at `rev`, sorted.
--- @param from_root string The old-layout git directory
--- @param rev string The revision to read the tree at
--- @return {string} | nil The ids
--- @return string Error message
local function list_ids(from_root: string, rev: string): {string} | nil, string
  local r = child.run({"git", "ls-tree", "-r", "--name-only", rev, "--", "items/"},
    {cwd = from_root})
  if r == nil or not r.ok then
    return nil, ("git ls-tree failed: %s"):format(r and r.stderr or "could not start")
  end
  local seen: {string: boolean} = {}
  local ids: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    local id = line:match("^items/([^/]+)%.tl$")
    if id and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  return ids
end

--- Split one NUL-joined `git log` line into its fields — plain
--- `string.find`, never a pattern, since a commit subject can hold
--- anything a Lua pattern would otherwise need escaping for.
--- @param line string One `%H\0%at\0%s`-formatted line
--- @return string sha, string at, string subject
local function split_log_line(line: string): string, string, string
  local a = line:find("\0", 1, true)
  local b = line:find("\0", a + 1, true)
  return line:sub(1, a - 1), line:sub(a + 1, b - 1), line:sub(b + 1)
end

--- One item's whole history, oldest first: every commit that touched
--- either of its two old-layout files.
--- @param from_root string The old-layout git directory
--- @param rev string The revision to walk from
--- @param id string The item id
--- @return {Commit} | nil The commits, oldest first
--- @return string Error message
local function log_for(from_root: string, rev: string, id: string): {Commit} | nil, string
  local r = child.run({"git", "log", "--reverse", "--format=%H%x00%at%x00%s", rev,
      "--", "items/" .. id .. ".tl", "items/" .. id .. ".md"}, {cwd = from_root})
  if r == nil or not r.ok then
    return nil, ("git log failed: %s"):format(r and r.stderr or "could not start")
  end
  local out: {Commit} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    local sha, at, subject = split_log_line(line)
    out[#out + 1] = {sha = sha, at = math.tointeger(tonumber(at)) or 0, subject = subject}
  end
  return out
end

--- The session a replayed commit's subject names, "" when none does —
--- every mutation verb's subject that records who acted says so as
--- "... by <session>" (`take ID by S`, `review ID claimed by S`,
--- `verdict ID accept by S`, ...), so one pattern covers them all.
--- @param subject string The commit subject
--- @return string The session name, "" when the subject names none
local function session_of(subject: string): string
  return subject:match(" by (%S+)") or ""
end

--- The repo-default rule the move itself needs: a non-root item that
--- never had `repo` set meant "the board's own origin" before the
--- board had a repository of its own to be explicit about — `base ==
--- "board"` is how that intent is recorded — and cosmic's own product
--- repo otherwise. Applied to every replayed revision alike, since the
--- ambiguity it resolves held at every point in the item's history,
--- not only its latest.
--- @param it item.Item The decoded item, mutated in place
local function apply_repo_default(it: item.Item)
  if item.is_root(it) or (it.repo or "") ~= "" then
    return
  end
  if it.base == "board" then
    it.repo, it.base = product.BOARD_REPO, "main"
  else
    it.repo = product.REPO
  end
end

--- Replay one item's whole history into the store as a fresh commit
--- chain, then push it — one item at a time, so a long import leaves
--- real, visible progress if it is interrupted partway.
--- @param s store.Store The target store
--- @param from_root string The old-layout git directory
--- @param rev string The revision to read history at
--- @param id string The item id
--- @return boolean True on success
--- @return string Error message
local function import_item(s: store.Store, from_root: string, rev: string,
    id: string): boolean, string
  local commits, lerr = log_for(from_root, rev, id)
  if commits == nil then
    return false, lerr
  end
  local queries: {string} = {}
  for _, c in ipairs(commits) do
    queries[#queries + 1] = c.sha .. ":items/" .. id .. ".tl"
    queries[#queries + 1] = c.sha .. ":items/" .. id .. ".md"
  end
  local batch, berr = gitobj.cat_file_batch(from_root, queries)
  if batch == nil then
    return false, berr
  end
  local parent_sha = refs.ZERO_SHA
  local ended = false
  for _, c in ipairs(commits) do
    local tl_entry = batch[c.sha .. ":items/" .. id .. ".tl"]
    if tl_entry ~= nil then
      local raw, perr = literal.parse(tl_entry.content)
      if raw == nil then
        return false, ("%s@%s: %s"):format(id, c.sha:sub(1, 7), perr)
      end
      local it, derr = item.decode(raw)
      if it == nil then
        return false, ("%s@%s: %s"):format(id, c.sha:sub(1, 7), derr)
      end
      apply_repo_default(it)
      local spec_body: string | nil = nil
      local md_entry = batch[c.sha .. ":items/" .. id .. ".md"]
      if md_entry ~= nil then
        spec_body = md_entry.content
      end
      local tree_sha, terr = itemtree.build_tree(s.root, it, spec_body)
      if tree_sha == nil then
        return false, terr
      end
      local session_name = session_of(c.subject)
      local author_name, author_email = TOOL_NAME, TOOL_EMAIL
      if session_name ~= "" then
        author_name, author_email = session_name, session_name .. "@board"
      end
      local when = ("%d +0000"):format(c.at)
      local parents: {string} = {}
      if parent_sha ~= refs.ZERO_SHA then
        parents = {parent_sha}
      end
      local commit_sha, cerr = gitobj.commit_tree(s.root, {
          tree = tree_sha, parents = parents, message = c.subject,
          author_name = author_name, author_email = author_email,
          author_date = when, committer_name = TOOL_NAME,
          committer_email = TOOL_EMAIL, committer_date = when, op = "import",
        })
      if commit_sha == nil then
        return false, cerr
      end
      parent_sha = commit_sha
      ended = (it.resolution or "") ~= ""
    end
  end
  if parent_sha == refs.ZERO_SHA then
    return true, ""
  end
  local ref = "refs/items/" .. id
  if ended then
    ref = "refs/ended/" .. id
  end
  local moved, uerr = refs.update_ref(s.root, ref, parent_sha, refs.ZERO_SHA)
  if not moved then
    return false, uerr
  end
  s.pending[#s.pending + 1] = {ref = ref, old = "", delete = false}
  return true, ""
end

--- Import every item under `items/` at `rev` in `from_root` into `s`,
--- replaying each one's full history and pushing it before moving to
--- the next.
--- @param s store.Store The target store
--- @param from_root string The old-layout git directory
--- @param rev string The revision to read history at
--- @return integer | nil The number of items imported
--- @return string Error message
local function run(s: store.Store, from_root: string, rev: string): integer | nil, string
  local ids, ierr = list_ids(from_root, rev)
  if ids == nil then
    return nil, ierr
  end
  for _, id in ipairs(ids) do
    local ok, err = import_item(s, from_root, rev, id)
    if not ok then
      return nil, ("%s: %s"):format(id, err)
    end
    local pushed, perr = publish.publish(s)
    if not pushed then
      return nil, ("%s: publish: %s"):format(id, perr)
    end
  end
  return #ids, ""
end

local record import
  type Commit = Commit
  list_ids: function(from_root: string, rev: string): {string} | nil, string
  session_of: function(subject: string): string
  run: function(s: store.Store, from_root: string, rev: string): integer | nil, string
end

local M: import = {
  list_ids = list_ids,
  session_of = session_of,
  run = run,
}

return M
