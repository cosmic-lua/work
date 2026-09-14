--- Git object projection for frozen format-6 transitions.
local git = require("_work.singlehead_git")
local tx = require("_work.statetransaction")
local fs = require("cosmic.fs")
local literal = require("_work.singlehead_literal")
local trailer_codec = require("_work.stateplan_trailers")
local ZERO < const > = string.rep("0", 40)
--- The object id one path holds at `head`, the zero id when absent — the fence
--- reads every recorded path through here, so an invalid path is refused rather
--- than resolved by git in some other way.
--- @param root string The repository holding `head`
--- @param head string The exact commit to read
--- @param path string The path to resolve
--- @return string | nil The object id, the zero id when the path is absent
--- @return string Error message
local function path_id(root: string, head: string, path: string): string | nil, string
  if not tx.path_ok(path) then return nil, "invalid dependency path" end
  local raw, err = git.run(root, {"--literal-pathspecs", "ls-tree", "-z", head, "--", path})
  if raw == nil then return nil, err end
  if raw == "" then return ZERO, "" end
  local id = raw:match("^%d+ %w+ ([0-9a-f]+)\t")
  return id, id and "" or "malformed tree entry"
end
--- The tree `head` becomes once these changes are applied, computed in a
--- private index file so nothing touches the checkout's own — which is what lets
--- a rebase and a bounded gate re-run happen with no working tree at all.
--- @param root string The repository holding `head`
--- @param head string The tree to start from
--- @param changes {tx.Change} The paths to write or remove
--- @return string | nil The resulting tree id
--- @return string Error message
local function apply(root: string, head: string, changes: {tx.Change}): string | nil, string
  local dir, err = fs.temp_dir(fs.join(os.getenv("TEST_TMPDIR") or "/tmp", "state-index-XXXXXX"))
  if dir == nil then return nil, err end
  local set = {GIT_INDEX_FILE = fs.join(dir, "index")}
  local function fail(why: string): string | nil, string
    local _removed, _rerr = fs.remove_all(dir)
    return nil, why
  end
  local _, rerr = git.run(root, {"read-tree", head}, nil, set)
  if rerr ~= "" then return fail(rerr) end
  for _, change in ipairs(changes) do
    local args: {string}
    if change.delete then args = {"update-index", "--force-remove", "--", change.path}
    else
      local sha, herr = git.text(root, {"hash-object", "-w", "--stdin"}, change.content)
      if sha == nil then return fail(herr) end
      args = {"update-index", "--add", "--cacheinfo", change.mode, sha, change.path}
    end
    local _, uerr = git.run(root, args, nil, set)
    if uerr ~= "" then return fail(uerr) end
  end
  local tree, terr = git.text(root, {"write-tree"}, nil, set)
  local _removed, _rerr = fs.remove_all(dir)
  return tree, terr
end
--- One transition as a commit on `parent`: the author is the session the
--- transition froze, the committer gitboard, and the message the frozen one with
--- its trailers already bound.
--- @param root string The repository to write the commit in
--- @param parent string The commit to parent it on
--- @param tree string The tree it carries
--- @param transition tx.Transition The frozen transition
--- @return string | nil The commit id
--- @return string Error message
local function commit(root: string, parent: string, tree: string, transition: tx.Transition): string | nil, string
  return git.text(root, {"commit-tree", tree, "-p", parent}, transition.message, {
      GIT_AUTHOR_NAME = transition.author.name, GIT_AUTHOR_EMAIL = transition.author.email,
      GIT_AUTHOR_DATE = transition.author.date, GIT_COMMITTER_NAME = "gitboard",
      GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = transition.author.date})
end
--- @param head Exact candidate tree whose complete leaf list must be preserved.
--- @param changes Frozen changed blobs to inline instead of referencing their SHA.
--- @return Every leaf, or refusal for unsupported entries such as gitlinks.
local function snapshot(root: string, head: string, changes: {tx.Change}): {{string: any}} | nil, string
  local listing, err = git.run(root, {"ls-tree", "-r", "-z", head})
  if listing == nil then return nil, err end
  local entries = literal.sequence() as {{string: any}} -- cast: explicit connector sequence
  local offset = 1
  while offset <= #listing do
    local ending = listing:find("\0", offset, true)
    if ending == nil then return nil, "unterminated native tree entry" end
    local row = listing:sub(offset, ending - 1)
    local mode, kind, sha, path = row:match("^(%d+) (%w+) ([0-9a-f]+)\t(.+)$")
    if mode == nil or kind ~= "blob" or #sha ~= 40
    or (mode ~= "100644" and mode ~= "100755" and mode ~= "120000") or not tx.path_ok(path) then
      return nil, "unsupported native tree entry; refusing to omit it"
    end
    local entry: {string: any} = {path = path, mode = mode, type = "blob", sha = sha}
    for _, change in ipairs(changes) do
      if change.path == path and not change.delete then entry.sha = nil; entry.content = change.content end
    end
    entries[#entries + 1] = entry
    offset = ending + 1
  end
  return entries, ""
end
--- One commit read back AS a transition — the diff against its parent as
--- changes, and its logical author from the `Gitboard-Author` trailer when it
--- carries one. This is how a candidate is compared with the attempt that was
--- frozen: the same shape from both sides, so confirmation compares content
--- rather than trusting a trailer.
--- @param root string The repository holding both commits
--- @param base string The parent commit
--- @param tip string The commit to read
--- @param dependencies {tx.Dependency} The fence to record on the result
--- @param publish_by integer | nil The deadline to record, 0 for none
--- @param bounded boolean | nil Whether the result is a bounded transition
--- @param gate string | nil Its gate name
--- @return tx.Transition | nil The transition this commit is
--- @return string Error message
local function capture(root: string, base: string, tip: string, dependencies: {tx.Dependency},
    publish_by?: integer, bounded?: boolean, gate?: string): tx.Transition | nil, string
  local raw, err = git.run(root, {"diff-tree", "--no-commit-id", "--no-renames", "-r", "--raw", "-z", base, tip})
  if raw == nil then return nil, err end
  local changes: {tx.Change} = {}
  local position = 1
  while position <= #raw do
    local boundary = raw:find("\0", position, true)
    if boundary == nil then return nil, "malformed transition diff" end
    local header = raw:sub(position, boundary - 1)
    local next_boundary = raw:find("\0", boundary + 1, true)
    if next_boundary == nil then return nil, "malformed transition path" end
    local path = raw:sub(boundary + 1, next_boundary - 1)
    local oldmode, newmode, _oldsha, newsha, status = header:match("^:(%d+) (%d+) ([0-9a-f]+) ([0-9a-f]+) (%u)$")
    if oldmode == nil then return nil, "unsupported transition diff" end
    local content = ""
    if status ~= "D" then
      local body, berr = git.run(root, {"cat-file", "blob", newsha})
      if body == nil then return nil, berr end
      content = body
    end
    changes[#changes + 1] = {path = path, mode = status == "D" and oldmode or newmode,
      content = content, delete = status == "D"}
    position = next_boundary + 1
  end
  local rawcommit, cerr = git.run(root, {"cat-file", "commit", tip})
  if rawcommit == nil then return nil, cerr end
  local name, email, date = rawcommit:match("\nauthor (.-) <([^>]+)> ([^\n]+)\n")
  local message = rawcommit:match("\n\n(.*)$")
  if name == nil or message == nil then return nil, "malformed transition commit" end
  local trailers, terr = trailer_codec.parse(message)
  if trailers == nil then return nil, terr end
  local logical = ("\n" .. trailers):match("\nGitboard%-Author: ([^\n]+)")
  if logical ~= nil then
    local decoded = literal.decode_object(logical)
    if decoded == nil then return nil, "invalid logical author" end
    local n, e, d = decoded.name, decoded.email, decoded.date
    if not (n is string) or not (e is string) or not (d is string) then return nil, "invalid logical author" end
    name, email, date = n, e, d
  end
  return {base = base, dependencies = dependencies, changes = changes, message = message,
    author = {name = name, email = email, date = date}, publish_by = publish_by or 0,
    bounded = bounded or false, gate = gate or ""}, ""
end
local record Module
  path_id: function(string, string, string): string | nil, string
  apply: function(string, string, {tx.Change}): string | nil, string
  commit: function(string, string, string, tx.Transition): string | nil, string
  snapshot: function(string, string, {tx.Change}): {{string: any}} | nil, string
  capture: function(root: string, base: string, tip: string, dependencies: {tx.Dependency}, publish_by?: integer, bounded?: boolean, gate?: string): tx.Transition | nil, string
end
local M: Module = {path_id = path_id, apply = apply, commit = commit, capture = capture, snapshot = snapshot}
return M
