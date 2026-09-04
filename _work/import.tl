--- The one-time move off the old layout: `items/<id>.tl` +
--- `items/<id>.md` files in a git directory, at a given revision,
--- become `refs/items/<id>`/`refs/ended/<id>` refs in the CURRENT
--- store — with every commit that ever touched an item replayed, in
--- order, under the original author date and the session its subject
--- named, so `gitboard show <id>` and `git log` on its ref read
--- exactly as they would have if the ref had existed from the start.
--- This is also how the tests build fixture history: a small git
--- directory in the old layout, imported into a scratch store.
---
--- The whole replay is ONE `git fast-import` stream (`_work.fastimport`):
--- every item's own chain of commits, oldest first, each one's path
--- changes computed the same way an ordinary save's are
--- (`fastimport.diff_item` against the PREVIOUS revision decoded, nil
--- for the first), `from` the previous commit's own mark rather than a
--- real sha, since it does not have one yet. One `for-each-ref` then
--- learns every chain's actual tip, and each item still pushes on its
--- own, in id order — the local write is one process regardless of
--- history size, but the visible, resumable progress a long import's
--- push loop gives stays exactly as it was.
local child = require("cosmic.child")
local fastimport = require("_work.fastimport")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
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

--- Build one item's replayed commit chain as fast-import `CommitPlan`s
--- — one per historical commit that touched either of its old-layout
--- files, oldest first, each diffed against the PREVIOUS revision the
--- same way an ordinary save diffs against `Store.leased_item`
--- (`fastimport.diff_item`; nil for the very first, so it carries
--- every field). Every commit in the chain targets the SAME ref,
--- decided once the chain's own final resolution is known: unlike an
--- ordinary mutation's ended-item move, there is no EXISTING
--- `refs/items/<id>` to transition off of here — this writes a
--- brand-new ref from nothing, so the right final name can be chosen
--- up front and never has to move.
--- @param from_root string The old-layout git directory
--- @param rev string The revision to read history at
--- @param id string The item id
--- @param mark_seq {integer} A shared, mutable one-element mark
--- counter, advanced across every item's chain so marks stay unique
--- over the WHOLE stream `run` builds
--- @return {fastimport.CommitPlan} | nil The chain, empty when the
--- item has no history to replay
--- @return string Error message
local function build_item_chain(from_root: string, rev: string, id: string,
    mark_seq: {integer}): {fastimport.CommitPlan} | nil, string
  local commits, lerr = log_for(from_root, rev, id)
  if commits == nil then
    return nil, lerr
  end
  local queries: {string} = {}
  for _, c in ipairs(commits) do
    queries[#queries + 1] = c.sha .. ":items/" .. id .. ".tl"
    queries[#queries + 1] = c.sha .. ":items/" .. id .. ".md"
  end
  local batch, berr = gitobj.cat_file_batch(from_root, queries)
  if batch == nil then
    return nil, berr
  end
  local plans: {fastimport.CommitPlan} = {}
  local prev_it: item.Item = nil
  local prev_spec = ""
  local prev_mark = ""
  local ended = false
  for _, c in ipairs(commits) do
    local tl_entry = batch[c.sha .. ":items/" .. id .. ".tl"]
    if tl_entry ~= nil then
      local raw, perr = literal.parse(tl_entry.content)
      if raw == nil then
        return nil, ("%s@%s: %s"):format(id, c.sha:sub(1, 7), perr)
      end
      local it, derr = item.decode(raw)
      if it == nil then
        return nil, ("%s@%s: %s"):format(id, c.sha:sub(1, 7), derr)
      end
      apply_repo_default(it)
      local spec_body = ""
      local md_entry = batch[c.sha .. ":items/" .. id .. ".md"]
      if md_entry ~= nil then
        spec_body = md_entry.content
      end
      local ops = fastimport.diff_item(prev_it, it, spec_body, prev_spec)
      local session_name = session_of(c.subject)
      local author_name, author_email = TOOL_NAME, TOOL_EMAIL
      if session_name ~= "" then
        author_name, author_email = session_name, session_name .. "@board"
      end
      local when = ("%d +0000"):format(c.at)
      mark_seq[1] = mark_seq[1] + 1
      local mark = ":" .. tostring(mark_seq[1])
      local from: string = nil
      if prev_mark ~= "" then
        from = prev_mark
      end
      plans[#plans + 1] = {
        ref = "refs/items/" .. id, from = from, mark = mark,
        author_name = author_name, author_email = author_email,
        author_date = when, committer_name = TOOL_NAME,
        committer_email = TOOL_EMAIL, committer_date = when,
        message = c.subject, op = "import", ops = ops,
      }
      prev_it, prev_spec, prev_mark = it, spec_body, mark
      ended = (it.resolution or "") ~= ""
    end
  end
  if #plans > 0 and ended then
    local final_ref = "refs/ended/" .. id
    for _, p in ipairs(plans) do
      p.ref = final_ref
    end
  end
  return plans, ""
end

--- Import every item under `items/` at `rev` in `from_root` into `s`:
--- every item's whole history built into ONE fast-import stream (one
--- process, whatever the import's size), read back in one more, then
--- pushed one item at a time in id order — the local write no longer
--- costs a process per historical commit, but a long import still
--- leaves real, visible, resumable progress if it is interrupted
--- partway through the push loop.
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
  local mark_seq: {integer} = {0}
  local all_plans: {fastimport.CommitPlan} = {}
  local chain_of: {string: {fastimport.CommitPlan}} = {}
  for _, id in ipairs(ids) do
    local plans, perr = build_item_chain(from_root, rev, id, mark_seq)
    if plans == nil then
      return nil, ("%s: %s"):format(id, perr)
    end
    if #plans > 0 then
      chain_of[id] = plans
      for _, p in ipairs(plans) do
        all_plans[#all_plans + 1] = p
      end
    end
  end
  if #all_plans > 0 then
    local ok, ferr = fastimport.run(s.root, all_plans)
    if not ok then
      return nil, ("fast-import: %s"):format(ferr)
    end
  end
  local patterns: {string} = {}
  for _, id in ipairs(ids) do
    local plans = chain_of[id]
    if plans ~= nil then
      patterns[#patterns + 1] = plans[#plans].ref
    end
  end
  local tip_of: {string: string} = {}
  if #patterns > 0 then
    local found, rerr = refs.for_each_ref(s.root, patterns)
    if found == nil then
      return nil, ("could not read back the imported refs: %s"):format(rerr)
    end
    for _, r in ipairs(found) do
      tip_of[r.refname] = r.sha
    end
  end
  for _, id in ipairs(ids) do
    local plans = chain_of[id]
    if plans ~= nil then
      local ref = plans[#plans].ref
      local tip = tip_of[ref]
      if tip == nil then
        return nil, ("%s: fast-import did not create %s"):format(id, ref)
      end
      s.pending = {{ref = ref, old = "", delete = false}}
      local pushed, perr = publish.publish(s)
      if not pushed then
        return nil, ("%s: publish: %s"):format(id, perr)
      end
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
