--- The board's layout version: `refs/heads/board/format`'s tree holds one
--- blob, `format`, carrying this text — the marker `gitread.list`
--- checks before trusting anything else it read alongside it, so a
--- board on a layout this tool cannot safely read (or, someday, a
--- future layout this tool predates) fails loudly and by name rather
--- than by whatever downstream field happens to come back missing or
--- misread. `store.init_repo` writes the marker on a board that has
--- none yet and nothing filed under it either — the one case an
--- absent marker is not itself the problem.
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")

--- Format 4 records one acquisition as a parentless shared commit under the
--- append-only `refs/heads/claim-batches/<batch-id>` namespace. Each member's
--- item ref advances through a first-parent bridge naming that same batch,
--- making the requested set an atomic shared fact rather than unrelated item
--- mutations.
local CURRENT < const > = "4"
local PREVIOUS < const > = "3"

--- Whether `found` is the one board layout this build can upgrade.
--- Migration is deliberately one-hop: accepting an arbitrary older
--- marker would silently skip transformations a future intermediate
--- layout may require.
--- @param found string The marker blob's content
--- @return boolean True only for the immediately previous layout
local function migratable(found: string): boolean
  return (found or ""):gsub("%s+$", "") == PREVIOUS
end

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
  if trimmed == PREVIOUS then
    return ("refs/heads/board/format is %s, this tool expects %s — run "
      .. "`gitboard migrate` before reading or writing the board")
    :format(trimmed, CURRENT)
  end
  return ("refs/heads/board/format is %s, this tool expects %s — it cannot safely "
    .. "read or write this board"):format(trimmed, CURRENT)
end

local record Inspection
  content: string
  sha: string
  has_items: boolean
end

--- Inspect the canonical marker without reading any item content. In remote
--- mode `refs.for_each_ref` reads caller-fetched tracking refs, so this never
--- performs network I/O and never mistakes a prepared local successor for
--- confirmed board state.
--- @param dir string Board repository
--- @return Inspection | nil Marker and board presence
--- @return string Error message
local function inspect(dir: string): Inspection | nil, string
  local found, ferr = refs.for_each_ref(dir,
    {"refs/heads/items", "refs/heads/ended", "refs/heads/board/format"})
  if found == nil then
    return nil, ferr
  end
  local format_sha = ""
  local has_items = false
  for _, entry in ipairs(found) do
    if entry.refname == "refs/heads/board/format" then
      format_sha = entry.sha
    elseif entry.refname:match("^refs/heads/items/") ~= nil
    or entry.refname:match("^refs/heads/ended/") ~= nil then
      has_items = true
    end
  end
  if format_sha == "" then
    return {content = "", sha = refs.ZERO_SHA, has_items = has_items}, ""
  end
  local objects, oerr = gitobj.cat_file_batch(dir, {format_sha .. ":format"})
  if objects == nil then
    return nil, oerr
  end
  local blob_entry = objects[format_sha .. ":format"]
  if blob_entry == nil or blob_entry.otype ~= "blob" then
    return nil, ("refs/heads/board/format has no readable format blob at %s")
    :format(format_sha)
  end
  return {content = blob_entry.content, sha = format_sha,
    has_items = has_items}, ""
end

--- Gate a write against the confirmed board format. Reads already gate in
--- `_work.gitread.list`; this separate check protects direct load→save paths
--- as well. Unlike a read of a virgin repository, a write requires the marker
--- to exist: `init` establishes it through its dedicated plumbing first.
--- @param dir string Board repository
--- @return boolean True only when the current marker exists
--- @return string Error message
local function require_current(dir: string): boolean, string
  local state, err = inspect(dir)
  if state == nil then
    return false, err
  end
  if state.sha == refs.ZERO_SHA then
    return false, "refs/heads/board/format is missing — run `gitboard init` first"
  end
  local denied = refusal(state.content, state.has_items)
  if denied ~= nil then
    return false, denied
  end
  return true, ""
end

--- Create `refs/heads/board/format` locally when this repository has
--- none yet. Publication is deliberately absent: initialization only
--- creates Git objects and local refs, and the caller owns transport.
--- A repository that already carries the ref locally is untouched.
--- @param dir string The directory to prepare
--- @return boolean True on success
--- @return string Error message
local function ensure(dir: string): boolean, string
  local found, ferr = refs.for_each_ref(dir, {"refs/heads/board/format"})
  if found == nil then
    return false, ferr
  end
  if #found == 0 then
    -- A remote-backed brand-new board has no fetched canonical marker until
    -- its caller publishes and fetches the seed. The local marker prepared by
    -- an earlier `init` is still authoritative for INIT IDEMPOTENCY only: do
    -- not try to recreate it with a ZERO_SHA lease on the second call. Normal
    -- readers continue to ignore this local head in remote mode.
    local local_found, lerr =
    refs.for_each_ref_raw(dir, {"refs/heads/board/format"})
    if local_found == nil then
      return false, lerr
    end
    if #local_found > 0 then
      local local_sha = local_found[1].sha
      local raw, rerr = gitobj.cat_file_batch(dir, {local_sha .. ":format"})
      if raw == nil then
        return false, rerr
      end
      local local_blob = raw[local_sha .. ":format"]
      if local_blob == nil or local_blob.otype ~= "blob" then
        return false, "local refs/heads/board/format has no readable format blob"
      end
      local denied = refusal(local_blob.content, true)
      if denied ~= nil then
        return false, denied
      end
      return true, ""
    end
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
  return true
end

local record format
  CURRENT: string
  PREVIOUS: string
  type Inspection = Inspection
  blob: function(): string
  migratable: function(found: string): boolean
  refusal: function(found: string, has_items: boolean): string | nil
  inspect: function(dir: string): Inspection | nil, string
  require_current: function(dir: string): boolean, string
  ensure: function(dir: string): boolean, string
end

local M: format = {
  CURRENT = CURRENT,
  PREVIOUS = PREVIOUS,
  blob = blob,
  migratable = migratable,
  refusal = refusal,
  inspect = inspect,
  require_current = require_current,
  ensure = ensure,
}

return M
