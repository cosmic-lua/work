--- One-hop format-4 to format-5 migration. Format 5 holds an item's
--- prose as the `spec/` subtree of two blobs (`change.md`,
--- `non-goals.md`) and carries what the prose used to declare as
--- fields: the paths a Change names (`touches`) and the repositories
--- an Access section names (`access`). Every item ref advances in the
--- same atomic prepared transaction as the format marker, so either
--- every ref and the marker move or none does, and nothing is left in
--- two shapes.
---
--- One format-4 `spec.md` becomes, per item: the `change` section's
--- text as `spec/change.md`, the `non-goals` section's as
--- `spec/non-goals.md`, and every other section — any text ahead of
--- the first heading, then each remaining heading with its own block
--- under it, in source order — as the migration commit's body, so
--- `git log` reads as the author wrote it. An `Acceptance` section is
--- dropped, not carried: it stays in the item's history on the commit
--- it was written in. `depends_on` is left empty — a citation in prose
--- is provenance or contrast as often as a dependency, and the
--- relation is declared afterwards with `gitboard depend`.
---
--- Every migration commit carries the run's own date, never one read
--- out of the content: this is the record of when the layout changed,
--- not of when the prose was written.
local cache = require("_work.cache")
local format = require("_work.format")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local overlap = require("_work.overlap")
local prepared = require("_work.prepared")
local refs = require("_work.refs")
local spec = require("_work.spec")

local record Outcome
  current: boolean
  applied: boolean
  transaction: prepared.Transaction | nil
  --- Item refs rewritten (every one on the board).
  moved: integer
  --- Items ending with a non-empty `spec/change.md`.
  with_change: integer
  --- Items ending with a non-empty `spec/non-goals.md`.
  with_non_goals: integer
  --- Items whose migration commit carries a body.
  with_body: integer
  --- Items ending with an EMPTY `change.md` — the refiner queue's size.
  no_change: integer
  --- `Acceptance` sections dropped rather than carried.
  dropped: integer
end

--- One `spec.md` classified: the two blobs, the commit body, and how
--- many `Acceptance` sections were dropped on the way.
local record Classified
  spec: itemtree.Spec
  body: string
  dropped: integer
end

--- The section-level heading whose block is dropped rather than
--- carried into the commit body.
local DROPPED < const > = "acceptance"

--- Classify one format-4 `spec.md` with `spec.segments` — fence-aware,
--- level-aware, thematic breaks as content — so a Change with `###`
--- subsections keeps all of them. A section-level `Acceptance` is
--- counted and dropped; every other section rides the body under its
--- own heading line, and text ahead of the first heading leads it.
--- @param text string The blob's content, "" when the item has none
--- @return Classified The two blobs, the body, and the dropped count
local function classify(text: string): Classified
  local change: {string} = {}
  local non_goals: {string} = {}
  local blocks: {string} = {}
  local dropped = 0
  for _, seg in ipairs(spec.segments(text)) do
    local lowered = seg.heading:lower()
    if seg.level == 0 then
      blocks[#blocks + 1] = seg.text
    elseif lowered == "change" then
      change[#change + 1] = seg.text
    elseif lowered == "non-goals" then
      non_goals[#non_goals + 1] = seg.text
    elseif lowered == DROPPED then
      dropped = dropped + 1
    else
      local line = ("#"):rep(seg.level) .. " " .. seg.heading .. "\n"
      if seg.text == "" then
        blocks[#blocks + 1] = line
      else
        blocks[#blocks + 1] = line .. "\n" .. seg.text
      end
    end
  end
  return {
    spec = {change = table.concat(change), non_goals = table.concat(non_goals)},
    body = (table.concat(blocks, "\n"):gsub("\n+$", "")),
    dropped = dropped,
  }
end

--- The `access` field the prose declared: every repository the
--- `## Access` section names, sorted for a deterministic tree, minus
--- the item's own `repo` — that one is read access by definition.
--- @param text string The whole `spec.md`
--- @param own string The item's `repo`, "" when unset
--- @return {string} Sorted slugs
local function declared_access(text: string, own: string): {string}
  local out: {string} = {}
  for slug in pairs(spec.declared_repos(text)) do
    if slug ~= own:lower() then
      out[#out + 1] = slug
    end
  end
  table.sort(out)
  return out
end

--- The `touches` field the prose declared: the path-shaped tokens the
--- Change names, kept as written whether or not they still exist —
--- a record of what the refiner declared, not a measurement.
--- `overlap.raw_paths_named` reads the Change section out of a whole
--- sidecar, so the already-split text is handed back under its heading.
--- @param change string The `change` blob
--- @return {string} Paths, first-seen order
local function declared_touches(change: string): {string}
  if change == "" then
    return {}
  end
  return overlap.raw_paths_named("## Change\n\n" .. change)
end

local function format_commit(root: string, prior: string,
    at: integer): string | nil, string
  local blob, berr = gitobj.hash_object_write(root, format.blob())
  if blob == nil then return nil, berr end
  local tree, terr = gitobj.mktree_write(root,
    {{mode = "100644", otype = "blob", sha = blob, name = "format"}})
  if tree == nil then return nil, terr end
  local date = ("%d +0000"):format(at)
  return gitobj.commit_tree(root, {tree = tree, parents = {prior},
      message = ("format %s"):format(format.CURRENT),
      author_name = "gitboard", author_email = "gitboard@board",
      author_date = date, committer_name = "gitboard",
      committer_email = "gitboard@board", committer_date = date,
      op = "migrate"})
end

--- The item's migration commit: its format-5 tree on top of `tip`,
--- the classified body as the message's remainder, both dates `at`.
local function migration_commit(root: string, it: item.Item,
    classified: Classified, tip: string, at: integer): string | nil, string
  local tree, terr = itemtree.build_tree(root, it, classified.spec, true)
  if tree == nil then return nil, terr end
  local message = ("migrate %s to format %s"):format(it.id:sub(-8),
    format.CURRENT)
  if classified.body ~= "" then
    message = message .. "\n\n" .. classified.body
  end
  local date = ("%d +0000"):format(at)
  return gitobj.commit_tree(root, {tree = tree, parents = {tip},
      message = message, author_name = "gitboard",
      author_email = "gitboard@board", author_date = date,
      committer_name = "gitboard", committer_email = "gitboard@board",
      committer_date = date, op = "migrate"})
end

local function migrate(root: string, now?: integer): Outcome | nil, string
  local state, serr = format.inspect(root)
  if state == nil then return nil, serr end
  local text = (state.content or ""):gsub("%s+$", "")
  local outcome: Outcome = {current = false, applied = false, transaction = nil,
    moved = 0, with_change = 0, with_non_goals = 0, with_body = 0,
    no_change = 0, dropped = 0}
  if text == format.CURRENT then
    outcome.current, outcome.applied = true, true
    return outcome, ""
  end
  if not format.migratable(state.content) then
    return nil, format.refusal(state.content, state.has_items)
    or ("cannot migrate board format %s"):format(text)
  end
  if state.sha == refs.ZERO_SHA then
    return nil, "cannot migrate a missing board format marker"
  end

  local board, berr = gitread.list(root, true)
  if board == nil then return nil, berr end
  if #board.duplicates > 0 then
    return nil, "repair duplicate items/ended refs before format migration"
  end
  local at = now or os.time()
  local updates: {prepared.Update} = {}
  -- The store's own spec reader answers a format-4 tree with the whole
  -- `spec.md` as `change`; this migration classifies the text itself,
  -- read straight from every frozen tip in one batch.
  local queries: {string} = {}
  for _, it in ipairs(board.items) do
    queries[#queries + 1] = board.shas_by_id[it.id] .. ":spec.md"
  end
  local blobs, lerr = gitobj.cat_file_batch(root, queries)
  if blobs == nil then return nil, lerr end
  for _, it in ipairs(board.items) do
    local tip = board.shas_by_id[it.id]
    local target = board.refs_by_id[it.id]
    local entry = blobs[tip .. ":spec.md"]
    local body = ""
    if entry ~= nil and entry.otype == "blob" then
      body = entry.content
    end
    local classified = classify(body)
    it.touches = declared_touches(classified.spec.change)
    it.access = declared_access(body, it.repo or "")
    it.depends_on = {}
    local next_tip, nerr = migration_commit(root, it, classified, tip, at)
    if next_tip == nil then
      return nil, ("%s: %s"):format(it.id:sub(-8), nerr)
    end
    updates[#updates + 1] = {ref = target, expected = tip, next = next_tip}
    outcome.moved = outcome.moved + 1
    if classified.spec.change ~= "" then
      outcome.with_change = outcome.with_change + 1
    else
      outcome.no_change = outcome.no_change + 1
    end
    if classified.spec.non_goals ~= "" then
      outcome.with_non_goals = outcome.with_non_goals + 1
    end
    if classified.body ~= "" then
      outcome.with_body = outcome.with_body + 1
    end
    outcome.dropped = outcome.dropped + classified.dropped
  end
  local next_format, ferr = format_commit(root, state.sha, at)
  if next_format == nil then return nil, ferr end
  updates[#updates + 1] = {ref = "refs/heads/board/format",
    expected = state.sha, next = next_format}

  local tx, perr = prepared.prepare(root, updates,
    ("migrate board format %s to %s"):format(format.PREVIOUS, format.CURRENT))
  if tx == nil then return nil, perr end
  outcome.transaction = tx
  if refs.board_mode(root) == "remote" then
    return outcome, ""
  end
  local promoted, proerr = prepared.promote_local(root, tx)
  if not promoted then return nil, proerr end
  local rebuilt, rerr = cache.rebuild(root)
  if rebuilt == nil then
    return nil, ("format migrated, but cache rebuild failed: %s"):format(rerr)
  end
  local closed, cerr = cache.close(rebuilt)
  if not closed then return nil, cerr end
  outcome.applied = true
  return outcome, ""
end

local record gitmigrate
  type Outcome = Outcome
  type Classified = Classified
  classify: function(text: string): Classified
  migrate: function(root: string, now?: integer): Outcome | nil, string
end

local M: gitmigrate = {classify = classify, migrate = migrate}
return M
