--- Preparing a fresh state repository: the git repository itself, the
--- mirror refspecs, the board-format marker, and the board item — the
--- one parentless item `new` files under when no `--parent` names
--- something else. Split out of `_work.store` to keep that module
--- under the repo's line cap; `_work.store.init_repo` re-exports
--- `init_repo` unchanged, so every caller still goes through there.
--- Also carries `linked_worktree_refusal`, the one guard every write
--- verb runs before its first commit — `init_repo` calls it directly,
--- and `_work.storewrite.save` requires this module for the same
--- function rather than duplicating the check.
local child = require("cosmic.child")
local fs = require("cosmic.fs")

--- The refusal a write earns when `dir` is a LINKED worktree of
--- another checkout — sharing that checkout's refs and, through it, a
--- push-capable `origin` — rather than a board repository of its own.
--- `git rev-parse --git-common-dir` and `--git-dir`, run from `dir`,
--- print the same path (`.git`) in a primary checkout and diverge
--- exactly when `dir` is linked, the common dir naming the checkout
--- it is linked to. nil when the two agree, or when `dir` has no
--- `.git` of its own yet — `init`'s ordinary case, which this must not
--- block; checked first and separately from the `rev-parse` pair,
--- since git itself does not stop at `dir` — with no `.git` there it
--- walks up to whatever repository (this checkout included) happens
--- to be its ancestor, which is never the question being asked.
--- @param dir string The directory to check
--- @return string | nil The refusal, or nil to proceed
local function linked_worktree_refusal(dir: string): string | nil
  if not fs.is_present(fs.join(dir, ".git")) then
    return nil
  end
  local common = child.run({"git", "rev-parse", "--git-common-dir"}, {cwd = dir})
  local git_dir = child.run({"git", "rev-parse", "--git-dir"}, {cwd = dir})
  if common == nil or not common.ok or git_dir == nil or not git_dir.ok then
    return nil
  end
  local common_dir = (common.stdout or ""):gsub("%s+$", "")
  local this_dir = (git_dir.stdout or ""):gsub("%s+$", "")
  if common_dir == this_dir then
    return nil
  end
  return ("REFUSED: %s is a linked worktree of %s — a builder's worktree is "
    .. "never a board; run board verbs from the orchestrator's checkout")
  :format(dir, common_dir)
end

local record storeinit
  linked_worktree_refusal: function(dir: string): string | nil
end

local M: storeinit = {
  linked_worktree_refusal = linked_worktree_refusal,
}

return M
