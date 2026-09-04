--- The board's layout version: `refs/heads/board/format`'s tree holds one
--- blob, `format`, carrying this text — the marker `gitread.list`
--- checks before trusting anything else it read alongside it, so a
--- board on a layout this tool cannot safely read (or, someday, a
--- future layout this tool predates) fails loudly and by name rather
--- than by whatever downstream field happens to come back missing or
--- misread. `store.init_repo` writes the marker on a board that has
--- none yet and nothing filed under it either — the one case an
--- absent marker is not itself the problem.
local child = require("cosmic.child")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")

local CURRENT < const > = "1"

--- The `format` blob's content: the version text plus its own
--- trailing newline, the same shape every other text blob this store
--- writes carries (`meta`, `spec.md`, a blocker's reason).
--- @return string The blob content
local function blob(): string
  return CURRENT .. "\n"
end

--- The refusal a board's format marker earns, or nil when it may be
--- trusted.
---
--- `found` is the marker blob's content exactly as read back —
--- trailing whitespace is trimmed here, so the caller never has to —
--- and "" when the ref, or the `format` entry under its tree, is
--- absent. An absent marker refuses only when the board already
--- carries at least one item ref: that combination is an OLD layout,
--- never a fresh one, since `init_repo` is what writes the marker and
--- a board with nothing filed yet has run nothing else that could be
--- inconsistent with it either.
--- @param found string The marker blob's content, "" when absent
--- @param has_items boolean Whether the board carries any item ref
--- @return string | nil The refusal
local function refusal(found: string, has_items: boolean): string | nil
  local trimmed = (found or ""):gsub("%s+$", "")
  if trimmed == CURRENT then
    return nil
  end
  if trimmed == "" then
    if not has_items then
      return nil
    end
    return ("refs/heads/board/format is missing on a board that already carries "
      .. "items — this is an old layout this tool predates; expected format "
      .. "%s (run `gitboard init` to write the marker, once every other "
      .. "clone of this board has moved past whatever changed it)"):format(CURRENT)
  end
  return ("refs/heads/board/format is %s, this tool expects %s — it cannot safely "
    .. "read or write this board"):format(trimmed, CURRENT)
end

--- Create `refs/heads/board/format` locally when this repository has none
--- yet, and best-effort push it to `origin` when one exists, so the
--- very first clone of a brand-new board is also the one that puts
--- the marker on the remote for every later clone to fetch. A
--- repository that already carries the ref locally (a clone of an
--- already-migrated board, or a second call over the same tree) is
--- untouched; the push is best-effort and never fails this itself —
--- a plain (non-forced) push that loses to a marker another clone
--- already pushed just means this checkout has not fetched it yet,
--- which the next ordinary sync resolves the same way it resolves any
--- other stale ref.
--- @param dir string The directory to prepare
--- @return boolean True on success
--- @return string Error message
local function ensure(dir: string): boolean, string
  local found, ferr = refs.for_each_ref(dir, {"refs/heads/board/format"})
  if found == nil then
    return false, ferr
  end
  if #found == 0 then
    -- The blob and tree this commit points at must actually exist in
    -- the odb before `commit_tree`/the push below can use them — the
    -- writing forms, not the pure id computation `_work.gitobj` uses
    -- everywhere an id only needs comparing, never creating.
    local blob_sha, berr = gitobj.hash_object_write(dir, blob())
    if blob_sha == nil then
      return false, berr
    end
    local tree_sha, terr = gitobj.mktree_write(dir,
      {{mode = "100644", otype = "blob", sha = blob_sha, name = "format"}})
    if tree_sha == nil then
      return false, terr
    end
    local commit_sha, cerr = gitobj.commit_tree(dir, {
        tree = tree_sha, parents = {}, message = "format " .. CURRENT,
        author_name = "Claude", author_email = "noreply@anthropic.com",
        committer_name = "Claude", committer_email = "noreply@anthropic.com",
      })
    if commit_sha == nil then
      return false, cerr
    end
    local moved, uerr =
    refs.update_ref(dir, "refs/heads/board/format", commit_sha, refs.ZERO_SHA)
    if not moved then
      return false, uerr
    end
  end
  local has_origin = child.run({"git", "remote"}, {cwd = dir})
  if has_origin ~= nil and has_origin.ok
  and has_origin.stdout:find("origin", 1, true) ~= nil then
    -- Best-effort: a losing push here just means another clone's
    -- push already landed the marker, which the next ordinary fetch
    -- picks up the same way it picks up any other stale ref.
    local _pushed, _perr = child.run({"git", "-c", "push.negotiate=false", "push",
        "origin", "refs/heads/board/format"}, {cwd = dir})
  end
  return true
end

local record format
  CURRENT: string
  blob: function(): string
  refusal: function(found: string, has_items: boolean): string | nil
  ensure: function(dir: string): boolean, string
end

local M: format = {
  CURRENT = CURRENT,
  blob = blob,
  refusal = refusal,
  ensure = ensure,
}

return M
