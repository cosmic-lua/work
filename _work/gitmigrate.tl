--- One-hop board format migration. Format 2 already stores items as independent
--- Git refs; format 3 only adds optional item fields and new claim/canonical-ref
--- semantics. Migration therefore advances `refs/heads/board/format` alone.
--- Every item ref, tree, commit, and history remains byte-for-byte untouched.
---
--- Remote-backed boards receive a normal prepared leased transaction. The
--- caller publishes and fetches it, then `refresh` confirms it and rebuilds the
--- disposable cache. Local-only boards promote the same manifest atomically and
--- rebuild immediately. No path in this module performs remote I/O.
local cache = require("_work.cache")
local claim = require("_work.claim")
local format = require("_work.format")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local record Outcome
  --- True when the board was already on the current format.
  current: boolean
  --- True when a local-only board was promoted and its cache rebuilt.
  applied: boolean
  --- Present for a newly prepared migration. On a local-only board its staging
  --- ref has already been confirmed and cleaned, but the manifest still
  --- describes exactly what was applied.
  transaction: prepared.Transaction | nil
end

--- Build format 3 as a child of the confirmed format-2 marker and either stage
--- it for caller-owned publication or atomically apply it in local-only mode.
--- @param root string Board repository
--- @return Outcome | nil Migration result
--- @return string Error message
local function migrate(root: string, now?: integer): Outcome | nil, string
  local state, serr = format.inspect(root)
  if state == nil then
    return nil, serr
  end
  local text = (state.content or ""):gsub("%s+$", "")
  if text == format.CURRENT then
    return {current = true, applied = true, transaction = nil}, ""
  end
  if not format.migratable(state.content) then
    local denied = format.refusal(state.content, state.has_items)
    return nil, denied or ("cannot migrate board format %s"):format(text)
  end
  if state.sha == refs.ZERO_SHA then
    return nil, "cannot migrate a missing board format marker"
  end

  -- Format 2 had no claim-control lineage. The format-3 reader can preserve
  -- such a claim by treating the item tip as its fallback root/clock, but a
  -- migration must not turn a still-live legacy lease into ambiguous state.
  -- Refuse until every legacy work/review claim has naturally aged past two
  -- hours. Five minutes of accepted future clock skew is accounted for by the
  -- actual tip timestamp; a timestamp farther ahead refuses outright.
  local board, board_err = gitread.list(root, true)
  if board == nil then
    return nil, board_err
  end
  local at = now or os.time()
  for _, it in ipairs(board.items) do
    local legacy_holder = it.claim or ""
    if legacy_holder == "" then
      legacy_holder = it.reviewer or ""
    end
    if legacy_holder ~= "" and (it.claim_base or "") == "" then
      local touched = board.touched_by_id[it.id] or 0
      if touched > at + claim.FUTURE_SKEW_S then
        return nil, ("legacy claim on %s has a timestamp more than five minutes "
          .. "in the future; repair the clock/history before migration")
        :format(it.id:sub(-8))
      end
      local expires = touched + claim.LEASE_S
      if at < expires then
        return nil, ("legacy claim on %s may remain active until %d; stop board "
          .. "writes and retry after its two-hour lease expires")
        :format(it.id:sub(-8), expires)
      end
    end
  end

  local blob, berr = gitobj.hash_object_write(root, format.blob())
  if blob == nil then
    return nil, berr
  end
  local tree, terr = gitobj.mktree_write(root, {
      {mode = "100644", otype = "blob", sha = blob, name = "format"},
    })
  if tree == nil then
    return nil, terr
  end
  local next_sha, cerr = gitobj.commit_tree(root, {
      tree = tree, parents = {state.sha},
      message = ("format %s"):format(format.CURRENT),
      author_name = "gitboard", author_email = "gitboard@board",
      committer_name = "gitboard", committer_email = "gitboard@board",
      op = "migrate",
    })
  if next_sha == nil then
    return nil, cerr
  end
  local tx, perr = prepared.prepare(root, {{
        ref = "refs/heads/board/format", expected = state.sha, next = next_sha,
      }}, ("migrate board format %s to %s"):format(format.PREVIOUS, format.CURRENT))
  if tx == nil then
    return nil, perr
  end
  if refs.board_mode(root) == "remote" then
    return {current = false, applied = false, transaction = tx}, ""
  end

  local promoted, proerr = prepared.promote_local(root, tx)
  if not promoted then
    return nil, proerr
  end
  -- The SQLite mirror is derived state. Rebuild rather than alter it in place:
  -- this also proves the unchanged format-2 item commits decode under format 3.
  local rebuilt, rerr = cache.rebuild(root)
  if rebuilt == nil then
    return nil, ("format migrated, but cache rebuild failed: %s"):format(rerr)
  end
  local closed, clerr = cache.close(rebuilt)
  if not closed then
    return nil, ("format migrated, but rebuilt cache could not close: %s")
    :format(clerr)
  end
  return {current = false, applied = true, transaction = tx}, ""
end

local record gitmigrate
  type Outcome = Outcome
  migrate: function(root: string, now?: integer): Outcome | nil, string
end

local M: gitmigrate = {
  migrate = migrate,
}

return M
