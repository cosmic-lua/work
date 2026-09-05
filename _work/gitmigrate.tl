--- `gitboard migrate [--dry-run]`: the one verb a layout-1 board is
--- not refused for (`_work.format.refusal` names it; the exemption
--- itself is threaded through `_work.gitread.list`'s
--- `allow_old_format` parameter, reached here via
--- `_work.storemigrate.list_for_migrate`). It reads the whole board, computes, in
--- memory, four things (`_work.gitmigrate_plan`, split out to keep
--- this file — and that one — under the line cap):
---
---   1. the board item: minted when no parentless item is already
---      titled "board"; every OTHER parentless item becomes its child
---   2. every parent's `order`, from the transitive closure of its
---      children's `beats` edges — the board included, since its
---      children are the former roots
---   3. every blocker's re-parent under the open waiter its
---      `blocked_by` edge names, arbitrated by rank when more than one
---      waiter claims the same blocker
---   4. every `edges/*` entry and `held` blob dropped
---
--- `--dry-run` prints the plan and writes nothing. Otherwise every
--- touched item, the board item, and `refs/heads/board/format`'s bump
--- to `2` land as ONE `git fast-import` stream and ONE atomic, leased
--- push (`gitwrite.save_batch`'s `extra_commits`, `publish.publish`) —
--- the same multi-ref mechanism every other mutation's `also` list
--- uses, never a second one. A lost race refuses the whole thing, same
--- as any other mutation; re-running the verb decides afresh. Running
--- it again on an already-migrated (format 2) board is refused outright.
local fastimport = require("_work.fastimport")
local gate = require("_work.gitgate")
local gitobj = require("_work.gitobj")
local gitwrite = require("_work.gitwrite")
local plan_mod = require("_work.gitmigrate_plan")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")
local storemigrate = require("_work.storemigrate")
local storewrite = require("_work.storewrite")

--- The tool's own git identity — the same one every other write in
--- this store uses.
local TOOL_NAME < const > = "Claude"
local TOOL_EMAIL < const > = "noreply@anthropic.com"

--- `refs/heads/board/format`'s raw content (trimmed, "" when the ref
--- or its `format` entry is absent) and its tip sha ("" the same way).
--- Read directly rather than through `_work.format`/`_work.gitread`,
--- since this is the one call that must see "1" without either
--- refusing it.
--- @param root string The repository root
--- @return string content
--- @return string sha
--- @return string err Error message; "" on success (absence is not an error)
local function read_format(root: string): string, string, string
  local found, ferr = refs.for_each_ref(root, {"refs/heads/board/format"})
  if found == nil then
    return "", "", ferr
  end
  if #found == 0 then
    return "", "", ""
  end
  local sha = found[1].sha
  local batch, berr = gitobj.cat_file_batch(root, {sha .. ":format"})
  if batch == nil then
    return "", sha, berr
  end
  local entry = batch[sha .. ":format"]
  local content = ""
  if entry ~= nil then
    content = (entry.content or ""):gsub("%s+$", "")
  end
  return content, sha, ""
end

--- The format ref's own bump to `2`, as an extra commit
--- `gitwrite.save_batch` lands in the same stream as every item.
--- @param format_sha string The ref's observed tip; "" if somehow absent
--- @param now string The commit date every commit in this save shares
--- @return fastimport.CommitPlan
local function format_bump(format_sha: string, now: string): fastimport.CommitPlan
  local from: string = nil
  if format_sha ~= "" then
    from = format_sha
  end
  return {
    ref = "refs/heads/board/format", from = from, author_name = TOOL_NAME,
    author_email = TOOL_EMAIL, author_date = now, committer_name = TOOL_NAME,
    committer_email = TOOL_EMAIL, committer_date = now, message = "format 2",
    op = "migrate", ops = {{path = "format", content = "2\n"}},
  }
end

--- Write the plan: every touched item, plus the format bump, in one
--- `gitwrite.save_batch` call, queued and pushed exactly the way
--- `storewrite.save` queues and `publish.publish` pushes any other
--- mutation's commits — `storewrite.save` itself is not used, since
--- its fixed signature carries no `also`-item validation past a single
--- primary item and no way to add `extra_commits`; this calls the same
--- two functions it is built on directly instead.
--- @param s store.Store The store
--- @param plan plan_mod.Plan The plan `build` computed
--- @return boolean True once every ref landed (or there was nothing to write)
--- @return string Error message; `store.LOST_RACE` for a lost race
local function write_plan(s: store.Store, plan: plan_mod.Plan): boolean, string
  for _, it in ipairs(plan.write_items) do
    local ok, verr = store.stage(s, it)
    if not ok then
      return false, ("%s: %s"):format(it.id:sub(1, 8), verr)
    end
  end
  local _content, format_sha, ferr = read_format(s.root)
  if ferr ~= "" then
    return false, ferr
  end
  local now = fastimport.git_date_now()
  local function no_spec(_id: string): string
    return ""
  end
  local outcome, oerr = gitwrite.save_batch({
      root = s.root, items = plan.write_items, message = "migrate: layout 1 -> 2",
      session = "", op = "migrate", spec_for_first = nil,
      leased_ref = s.leased_ref, leased_sha = s.leased_sha, leased_item = s.leased_item,
      bounded = false, seq_sha = s.observed_seq, read_spec = no_spec,
      drop_held = plan.drop_held, extra_commits = {format_bump(format_sha, now)},
    })
  if outcome == nil then
    return false, oerr
  end
  for _, p in ipairs(outcome.pushes) do
    storewrite.add_pending(s, p)
  end
  return publish.publish(s)
end

--- `gitboard migrate [--dry-run]`.
--- @param s store.Store The store
--- @param dry_run boolean True to print the plan and write nothing
--- @return integer 0 on success, 1 otherwise
local function cmd_migrate(s: store.Store, dry_run: boolean): integer
  local content, _sha, ferr = read_format(s.root)
  if ferr ~= "" then
    return gate.verdict_line("migrate", false, ferr)
  end
  if content == "2" then
    return gate.verdict_line("migrate", false, "already on layout 2")
  end
  if content ~= "1" then
    local shown = content
    if shown == "" then
      shown = "<missing>"
    end
    return gate.verdict_line("migrate", false,
      ("cannot migrate from format %s — only layout 1 is supported"):format(shown))
  end
  local items, err = storemigrate.list_for_migrate(s)
  if items == nil then
    return gate.verdict_line("migrate", false, err)
  end
  local plan = plan_mod.build(items)
  for _, line in ipairs(plan.lines) do
    print(line)
  end
  if dry_run then
    return gate.verdict_line("migrate", true,
      ("dry run: %d item(s) would be rewritten, format 1 -> 2"):format(#plan.write_items))
  end
  local ok, werr = write_plan(s, plan)
  if not ok then
    return gate.verdict_line("migrate", false, werr)
  end
  return gate.verdict_line("migrate", true,
    ("%d items rewritten, format 2"):format(#plan.write_items))
end

local record gitmigrate
  cmd_migrate: function(s: store.Store, dry_run: boolean): integer
end

local M: gitmigrate = {
  cmd_migrate = cmd_migrate,
}

return M
