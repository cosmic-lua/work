--- Preparing a fresh state repository: the git repository itself, the
--- mirror refspecs, the board-format marker, and the board item — the
--- one parentless item `new` files under when no `--parent` names
--- something else. Split out of `_work.store` to keep that module
--- under the repo's line cap; `_work.store.init_repo` re-exports
--- `init_repo` unchanged, so every caller still goes through there.
local child = require("cosmic.child")
local format = require("_work.format")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local refs = require("_work.refs")

--- Create the board item — the one parentless item, titled "board" —
--- on a repository that has none yet: a repository already carrying
--- one (a clone of an already-initialized board, or a second call over
--- the same tree) is untouched. Mirrors `format.ensure`'s own shape:
--- the tree, commit, and ref are written directly (`itemtree.build_tree`
--- with `write`, `gitobj.commit_tree`, `refs.update_ref`), then
--- best-effort pushed to `origin` when one exists, so the first clone
--- of a brand-new board is also the one that puts it on the remote for
--- every later clone to fetch — a plain (non-forced) push that loses to
--- a board another clone already pushed just means this checkout has
--- not fetched it yet, resolved the same way any other stale ref is.
--- @param dir string The directory to prepare
--- @return boolean True on success
--- @return string Error message
local function ensure_board(dir: string): boolean, string
  local board, berr = gitread.list(dir)
  if board == nil then
    return false, berr
  end
  for _, existing in ipairs(board.items) do
    if (existing.parent or "") == "" then
      return true, ""
    end
  end
  local id = ksuid.new()
  local it: item.Item = {
    id = id, title = "board", parent = "", repo = "", base = "", key = "",
    order = {}, claim = "", builders = {}, speccers = {}, reviewer = "",
    pr = 0, result = "", verdict = "", verdict_head = "", verdict_spec = "",
    resolution = "",
  }
  local tree_sha, terr = itemtree.build_tree(dir, it, nil, true)
  if tree_sha == nil then
    return false, terr
  end
  local commit_sha, cerr = gitobj.commit_tree(dir, {
      tree = tree_sha, parents = {}, message = "board",
      author_name = "Claude", author_email = "noreply@anthropic.com",
      committer_name = "Claude", committer_email = "noreply@anthropic.com",
    })
  if commit_sha == nil then
    return false, cerr
  end
  local moved, uerr =
  refs.update_ref(dir, "refs/heads/items/" .. id, commit_sha, refs.ZERO_SHA)
  if not moved then
    return false, uerr
  end
  local has_origin = child.run({"git", "remote"}, {cwd = dir})
  if has_origin ~= nil and has_origin.ok
  and has_origin.stdout:find("origin", 1, true) ~= nil then
    -- Best-effort, exactly as `format.ensure`'s own push is: a losing
    -- push here just means another clone's push already landed the
    -- board, which the next ordinary fetch picks up like any other
    -- stale ref.
    local _pushed, _perr = child.run({"git", "-c", "push.negotiate=false", "push",
        "origin", "refs/heads/items/" .. id}, {cwd = dir})
  end
  return true, ""
end

--- Create a state repository at `dir`: a git repository (initialized
--- when none is there yet), with the mirror refspecs ADDED to
--- `remote.origin.fetch` (`refs.ensure_refspecs`; `sync` adds them too,
--- so a plain clone needs no `init` to read the board), `refs/heads/board/format`
--- created (and best-effort pushed) when this repository has none yet
--- (`format.ensure`), and the board item itself created the same way
--- when this repository carries none (`ensure_board`) — the one
--- parentless item `new` files under when no `--parent` names
--- something else. `git clone` already gave `origin` its own
--- default refspec for the checked-out branch (how the machinery
--- itself stays pullable) — this only adds the three item-ref
--- patterns beside it, never replacing what was there, so a plain
--- `git pull` on the branch keeps working. There is no `items/`
--- directory to create — every item lives as a ref, not a file — so a
--- fresh repository with nothing filed yet needs nothing else here —
--- for a board with nothing filed. A clone of a populated origin still
--- needs `publish.sync` before its `refs/heads/items/*` exist locally;
--- the verbs' `--dir` path assumes it ran.
--- @param dir string The directory to prepare
--- @return boolean True on success
--- @return string Error message
local function init_repo(dir: string): boolean, string
  if not fs.is_dir(fs.join(dir, ".git")) then
    local r, err = child.run({"git", "init", "-q", dir})
    if r == nil or not r.ok then
      return false, err or (r and r.stderr) or "git init failed"
    end
  end
  local specs_ok, serr = refs.ensure_refspecs(dir)
  if not specs_ok then
    return false, serr
  end
  local ensured, eerr = format.ensure(dir)
  if not ensured then
    return false, eerr
  end
  local boarded, boerr = ensure_board(dir)
  if not boarded then
    return false, boerr
  end
  return true, ""
end

local record storeinit
  init_repo: function(dir: string): boolean, string
end

local M: storeinit = {
  init_repo = init_repo,
}

return M
