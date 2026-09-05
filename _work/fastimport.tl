--- One `git fast-import` stream per save, replacing the
--- `hash-object`/`mktree`/`commit-tree`/`update-ref` chain a naive
--- item write would otherwise spend one process per blob and tree on:
--- the pure diff half (`diff_item`, deciding which paths actually
--- moved, in-process, against no git at all) and the stream-building
--- half (`build_stream`/`run`), which turns that diff into ONE
--- `commit <ref>` block per item plus, for a bounded mutation, one
--- more for `refs/heads/board/seq` — fed to a single `git fast-import`
--- process regardless of how many items or paths are touched.
---
--- `from <observed tip>` on an existing item's commit means only the
--- paths a diff actually found different need an `M`/`D` at all —
--- everything else carries over from the parent tree unchanged, the
--- same tree fast-import ends up building being byte-identical to one
--- `_work.itemtree.build_tree`'s `mktree` chain would produce from
--- scratch, since a git tree is canonical: the same final set of
--- (mode, name, blob) entries hashes the same regardless of how it
--- was assembled. `from` is omitted only for a brand-new item, whose
--- first commit must have no parent.
---
--- fast-import refuses a non-fast-forward `commit <ref>` (a `from`
--- that does not match the ref's actual current tip) by silently NOT
--- moving the ref and warning on stderr — never a non-zero exit,
--- never `--force` here to push past it, since that silent refusal is
--- exactly the local compare-and-swap `git update-ref <ref> <new>
--- <old>` used to provide. `run` treats "the ref did not move" as the
--- failure it is; the caller (`_work.gitwrite`) is the one that knows
--- each ref's observed tip well enough to tell moved from unmoved.
local child = require("cosmic.child")
local itemtree = require("_work.itemtree")
local item = require("_work.item")
local time = require("cosmic.time")

--- One path change a commit carries: replace `path` with `content`,
--- or delete it when `content` is nil. Every path this item's tree
--- can hold — `meta`, `spec.md`, `held`, `edges/<kind>/<id>` — is a
--- single file, so one flat list of these (nested paths and all) is
--- the whole of what one item's commit needs to say.
local record Op
  path: string
  --- nil deletes the path; "" is a legal blob (the beats marker, an
  --- empty blocker reason) and is NOT a delete.
  content: string
end

--- One commit `build_stream` writes: the ref it lands on, the parent
--- to build from (nil for a brand-new item's root commit, or a mark
--- reference like ":3" for a replayed chain — see `_work.import`),
--- the identities and dates on both sides, the message and its `Op:`
--- trailer, and the path changes it carries. `mark`, when set, is
--- registered on this commit so a LATER commit in the same stream can
--- reference it via `from`/`merge` before it has a real sha.
local record CommitPlan
  ref: string
  from: string
  mark: string
  author_name: string
  author_email: string
  author_date: string
  committer_name: string
  committer_email: string
  committer_date: string
  message: string
  op: string
  ops: {Op}
end

--- "now", in the raw `<epoch> <+HHMM>` form both `git commit-tree`'s
--- `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` and fast-import's commit
--- date field accept — the same shape `_work.import` already uses for
--- a replayed commit's historical date, computed instead from the
--- current wall clock and this process's local offset.
--- @return string The date
local function git_date_now(): string
  local secs = os.time()
  local off = 0
  local dt = time.localtime(secs)
  if dt ~= nil then
    off = dt.gmtoff or 0
  end
  local sign = "+"
  if off < 0 then
    sign = "-"
    off = -off
  end
  local hh = off // 3600
  local mm = (off % 3600) // 60
  return ("%d %s%02d%02d"):format(secs, sign, hh, mm)
end

--- The paths one item's commit must change: `meta` when any scalar
--- field moved (compared as the one encoded blob `_work.itemtree`
--- already builds it as, never field by field), `spec.md` only when
--- `spec_replacement` is given AND differs from `old_spec` (nil
--- leaves the sidecar untouched — no read, no write, no path at all,
--- carried forward by `from`), `order` added, changed or removed when
--- the ranked child list moved (compared as its own encoded blob, the
--- same way `meta` is), `held` added or removed when `is_held`
--- flips, and every `edges/<kind>/<id>` entry — `beats`, `blocked_by`,
--- and every kind in `other_edges` — added, changed or removed against
--- `old`'s own sets. `old` is nil for a brand-new item — every path
--- the new item carries is then "added".
--- @param old item.Item | nil The item as last observed, nil when new
--- @param new_it item.Item The item as it stands now
--- @param spec_replacement string | nil Replacement spec.md text; nil
--- to leave the sidecar exactly as observed
--- @param old_spec string The sidecar's current text; read only when
--- `spec_replacement` is not nil, ignored otherwise
--- @return {Op} The path changes, possibly empty (a true no-op item)
local function diff_item(old: item.Item | nil, new_it: item.Item,
    spec_replacement: string | nil, old_spec: string): {Op}
  local ops: {Op} = {}
  local new_meta = itemtree.encode_meta(new_it)
  local old_meta: string = nil
  if old ~= nil then
    old_meta = itemtree.encode_meta(old)
  end
  if new_meta ~= old_meta then
    ops[#ops + 1] = {path = "meta", content = new_meta}
  end
  if spec_replacement ~= nil and spec_replacement ~= old_spec then
    if spec_replacement == "" then
      ops[#ops + 1] = {path = "spec.md", content = nil}
    else
      ops[#ops + 1] = {path = "spec.md", content = spec_replacement}
    end
  end
  local old_order = ""
  if old ~= nil then
    old_order = itemtree.encode_order(old.order or {})
  end
  local new_order = itemtree.encode_order(new_it.order or {})
  if new_order ~= old_order then
    if new_order == "" then
      ops[#ops + 1] = {path = "order", content = nil}
    else
      ops[#ops + 1] = {path = "order", content = new_order}
    end
  end
  local old_held = old ~= nil and old.is_held or false
  local new_held = new_it.is_held or false
  if new_held ~= old_held then
    if new_held then
      ops[#ops + 1] = {path = "held", content = ""}
    else
      ops[#ops + 1] = {path = "held", content = nil}
    end
  end
  local old_beats: {string: boolean} = {}
  if old ~= nil then
    for _, b in ipairs(old.beats or {}) do
      old_beats[b] = true
    end
  end
  local new_beats: {string: boolean} = {}
  for _, b in ipairs(new_it.beats or {}) do
    new_beats[b] = true
  end
  for b in pairs(new_beats) do
    if not old_beats[b] then
      ops[#ops + 1] = {path = "edges/beats/" .. b, content = ""}
    end
  end
  for b in pairs(old_beats) do
    if not new_beats[b] then
      ops[#ops + 1] = {path = "edges/beats/" .. b, content = nil}
    end
  end
  local old_blocked: {string: string} = {}
  if old ~= nil then
    for _, b in ipairs(old.blocked_by or {}) do
      old_blocked[b] = (old.block_reason or {})[b] or ""
    end
  end
  local new_blocked: {string: string} = {}
  for _, b in ipairs(new_it.blocked_by or {}) do
    new_blocked[b] = (new_it.block_reason or {})[b] or ""
  end
  for b, reason in pairs(new_blocked) do
    if old_blocked[b] == nil or old_blocked[b] ~= reason then
      ops[#ops + 1] = {path = "edges/blocked_by/" .. b, content = reason}
    end
  end
  for b in pairs(old_blocked) do
    if new_blocked[b] == nil then
      ops[#ops + 1] = {path = "edges/blocked_by/" .. b, content = nil}
    end
  end
  -- Every OTHER kind, unknown to this build: diffed the same shape as
  -- `blocked_by` (id -> content), one subtree per kind, so a kind this
  -- reader does not interpret still round-trips through an unrelated
  -- write untouched, and only the ids that actually moved get an op.
  local old_other: {string: {string: string}} = (old ~= nil and old.other_edges) or {}
  local new_other: {string: {string: string}} = new_it.other_edges or {}
  local kinds: {string: boolean} = {}
  for k in pairs(old_other) do
    kinds[k] = true
  end
  for k in pairs(new_other) do
    kinds[k] = true
  end
  for kind in pairs(kinds) do
    local old_map = old_other[kind] or {}
    local new_map = new_other[kind] or {}
    for eid, content in pairs(new_map) do
      if old_map[eid] == nil or old_map[eid] ~= content then
        ops[#ops + 1] = {path = ("edges/%s/%s"):format(kind, eid), content = content}
      end
    end
    for eid in pairs(old_map) do
      if new_map[eid] == nil then
        ops[#ops + 1] = {path = ("edges/%s/%s"):format(kind, eid), content = nil}
      end
    end
  end
  return ops
end

--- One `data <n>\n<content>\n` block: the byte count never includes
--- the trailing newline this always adds — that newline is pure
--- stream punctuation, the same way `cat-file --batch`'s reply skips
--- one trailing byte after every object's own content
--- (`_work.gitobj.cat_file_batch`) — never part of the object itself.
--- @param content string The exact bytes to carry
--- @return string The `data` block, newline-terminated
local function data_block(content: string): string
  return ("data %d\n%s\n"):format(#content, content)
end

--- One `commit` block's text.
--- @param c CommitPlan The commit to render
--- @return string The block's text
local function commit_block(c: CommitPlan): string
  local parts: {string} = {}
  parts[#parts + 1] = "commit " .. c.ref .. "\n"
  if (c.mark or "") ~= "" then
    parts[#parts + 1] = "mark " .. c.mark .. "\n"
  end
  parts[#parts + 1] = ("author %s <%s> %s\n"):format(
    c.author_name, c.author_email, c.author_date)
  parts[#parts + 1] = ("committer %s <%s> %s\n"):format(
    c.committer_name, c.committer_email, c.committer_date)
  local msg = c.message
  if (c.op or "") ~= "" then
    msg = msg .. "\n\nOp: " .. c.op
  end
  parts[#parts + 1] = data_block(msg .. "\n")
  if (c.from or "") ~= "" then
    parts[#parts + 1] = "from " .. c.from .. "\n"
  end
  for _, op in ipairs(c.ops) do
    if op.content == nil then
      parts[#parts + 1] = "D " .. op.path .. "\n"
    else
      parts[#parts + 1] = "M 100644 inline " .. op.path .. "\n"
      parts[#parts + 1] = data_block(op.content)
    end
  end
  return table.concat(parts)
end

--- The whole stream `run` feeds to `git fast-import --done`: every
--- commit's block, in order, terminated by `done` — required because
--- `run` passes `--done` itself, which refuses an incomplete stream
--- rather than silently accepting a truncated one.
--- @param commits {CommitPlan} The commits to write, in order
--- @return string The stream text
local function build_stream(commits: {CommitPlan}): string
  local parts: {string} = {}
  for _, c in ipairs(commits) do
    parts[#parts + 1] = commit_block(c)
  end
  parts[#parts + 1] = "done\n"
  return table.concat(parts)
end

--- Feed one stream to `git fast-import`. Never `--force`: a
--- non-fast-forward `from` is refused by fast-import itself (silently
--- — no ref moves, no non-zero exit, only a warning on stderr), which
--- is the safety net a plain `update-ref <ref> <new> <old>` used to
--- provide; the caller is the one positioned to tell a genuinely
--- unmoved ref from an intentionally untouched one, by comparing
--- against the tips it observed before calling this.
--- @param root string The repository root
--- @param commits {CommitPlan} The commits to write, in order
--- @return boolean True once fast-import exits cleanly (a ref it
--- silently refused to move is NOT itself a failure here — the
--- caller's own post-import check is what catches that)
--- @return string Error message when the process itself failed
local function run(root: string, commits: {CommitPlan}): boolean, string
  local stream = build_stream(commits)
  local r, err = child.run(
    {"git", "-c", "core.createObject=rename", "fast-import", "--quiet", "--done"},
    {cwd = root, stdin = stream})
  if r == nil then
    return false, err
  end
  if not r.ok then
    local detail = (r.stderr or ""):gsub("%s+$", "")
    return false, ("git fast-import failed: %s"):format(detail)
  end
  return true, ""
end

local record fastimport
  type Op = Op
  type CommitPlan = CommitPlan
  git_date_now: function(): string
  diff_item: function(old: item.Item | nil, new_it: item.Item,
  spec_replacement: string | nil, old_spec: string): {Op}
  data_block: function(content: string): string
  build_stream: function(commits: {CommitPlan}): string
  run: function(root: string, commits: {CommitPlan}): boolean, string
end

local M: fastimport = {
  git_date_now = git_date_now,
  diff_item = diff_item,
  data_block = data_block,
  build_stream = build_stream,
  run = run,
}

return M
