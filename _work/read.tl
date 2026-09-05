--- Typed readers over `_work.readddl`'s derived views: one function
--- per view, returning Teal records instead of raw SQLite rows. Every
--- function takes an already-open `_work.index.Index` — a plain
--- in-memory index from `_work.index.open`, or `_work.cache`'s
--- identically-shaped `Cache` — with `_work.index_rank.ensure_views`
--- and then `_work.readddl.ensure_views` already applied, in that
--- order: `readddl`'s views join against `rank_path`/`dense_rank`, so
--- those must exist first.
---
--- Fallible: `value | nil, string`, nothing in a third slot. A single-
--- row reader that finds no row reports "no such item" as the error;
--- a list reader that finds nothing returns an empty list, not an
--- error — the same convention `_work.ciobs.read` and
--- `_work.index_rank.rank_of` already use for a `query_one` that
--- matched nothing.
local index = require("_work.index")

local type Index = index.Index

--- One `queue` row: a work item's place in the one queue every verb
--- walks — stage first, then rank-path key, then id — before the
--- seeded per-session tie-break `next` applies over tied rows.
local record QueueRow
  id: string
  stage: integer
  key: string
end

--- One `outcomes` row: a positioned outcome plus whether an open
--- non-outcome item already stands under it (`live`), which is what
--- intake reads to skip an outcome that has work in flight.
local record OutcomeRow
  id: string
  key: string
  live: boolean
end

--- One `children` row: a listed child, its dense position (nil when
--- unranked among its siblings), and whether the child itself is open.
local record ChildRow
  child: string
  position: integer | nil
  open: boolean
end

--- One `structure` row: a whole-board audit finding, one of the five
--- kinds `_work.readddl`'s `structure` view derives.
local record StructureRow
  kind: string
  id: string
  detail: string
end

--- One `stale` row: a claim or review claim standing past its lease.
local record StaleRow
  id: string
  kind: string
  age_s: integer
end

--- `query_one`'s nil branch, resolved to a real failure when one
--- happened, or to `label` when the query simply found no row — the
--- one rule every single-row reader below shares.
--- @param err string | nil The second return from `query_one`
--- @param label string The error to report when nothing failed
--- @return string The error to return
local function absent(err: string | nil, label: string): string
  if err ~= nil and err ~= "" then
    return err
  end
  return label
end

--- Whether `id` names a real item — the shared existence check
--- `is_ranked` and `key` both need before trusting `rank_path`'s
--- absence to mean "broken or over-deep chain" rather than "no such
--- item at all".
--- @param c Index The index
--- @param id string The item's id
--- @return boolean | nil Whether it exists
--- @return string Error message
local function item_exists(c: Index, id: string): boolean | nil, string
  local row, err = c.db:query_one("SELECT 1 AS x FROM items WHERE id = ?", {id})
  if row == nil then
    if err ~= nil and err ~= "" then
      return nil, err
    end
    return false, ""
  end
  return true, ""
end

--- The role `_work.flow.role` derives for `id` — every item gets one,
--- open or done.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param id string The item's id
--- @return string | nil "board" | "outcome" | "container" | "work"
--- @return string Error message
local function role(c: Index, id: string): string | nil, string
  local row, err = c.db:query_one("SELECT role FROM role WHERE id = ?", {id})
  if row == nil then
    return nil, absent(err, ("read: no such item: %s"):format(id))
  end
  return row.role as string, "" -- cast: from any (sqlite row)
end

--- `_work.flow.is_doing`/the resolution rule, read back from the
--- `state` view.
--- @param c Index An index with `_work.index`'s base DDL applied
--- @param id string The item's id
--- @return string | nil "ended" | "doing" | "todo"
--- @return string Error message
local function state(c: Index, id: string): string | nil, string
  local row, err = c.db:query_one("SELECT state FROM state WHERE id = ?", {id})
  if row == nil then
    return nil, absent(err, ("read: no such item: %s"):format(id))
  end
  return row.state as string, "" -- cast: from any (sqlite row)
end

--- `_work.flow.substate` with no `queued` argument, read back from the
--- `substate` view — an accepted item reads as an ordinary wait, since
--- the store has no live GitHub read to say it is already queued to
--- merge.
--- @param c Index An index with `_work.index`'s base DDL applied
--- @param id string The item's id
--- @return string | nil "accepted" | "rework" | "review" | "building"
--- @return string Error message
local function substate(c: Index, id: string): string | nil, string
  local row, err = c.db:query_one("SELECT substate FROM substate WHERE id = ?", {id})
  if row == nil then
    return nil, absent(err, ("read: no such item: %s"):format(id))
  end
  return row.substate as string, "" -- cast: from any (sqlite row)
end

--- Whether `id`'s outcome is positioned in the board's own `order` —
--- `_work.rank.is_ranked` read back from `rank_path`. False, not an
--- error, for an item absent from `rank_path` (a broken or over-deep
--- chain) — the same "unplaced" answer `rank.is_ranked` gives it via
--- its one-entry, unpositioned fallback chain.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param id string The item's id
--- @return boolean | nil
--- @return string Error message
local function is_ranked(c: Index, id: string): boolean | nil, string
  local exists, eerr = item_exists(c, id)
  if not exists then
    return nil, absent(eerr, ("read: no such item: %s"):format(id))
  end
  local row, rerr = c.db:query_one("SELECT placed FROM rank_path WHERE id = ?", {id})
  if row == nil then
    if rerr ~= nil and rerr ~= "" then
      return nil, rerr
    end
    return false, ""
  end
  local placed = math.tointeger(row.placed as number) or 0 -- cast: from any (sqlite row)
  return placed == 1, ""
end

--- `id`'s sortable rank-path key — `_work.rank.key` read back from
--- `rank_path`, with the same single-field fallback ("1" plus the
--- item's own id) for an item `rank_path` carries no row for. A
--- POSITIONED field's digits run one higher than `_work.rank.key`'s
--- own (`_work.index_rank`'s SQL numbers a dense position with
--- `ROW_NUMBER()`, 1-based, where `_work.rank.dense_positions` numbers
--- the same list 0-based) — a pre-existing offset in `_work.index_rank`
--- this slice does not touch. It changes no comparison's outcome (see
--- `_work.read_test.test_key_agrees_with_rank_order`): sort order and
--- the "0"/"1" leading digit against an unpositioned sibling are both
--- unaffected by a shift applied uniformly on both sides of every
--- positioned comparison.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param id string The item's id
--- @return string | nil The key
--- @return string Error message
local function key(c: Index, id: string): string | nil, string
  local exists, eerr = item_exists(c, id)
  if not exists then
    return nil, absent(eerr, ("read: no such item: %s"):format(id))
  end
  local row, rerr = c.db:query_one("SELECT key FROM rank_path WHERE id = ?", {id})
  if row == nil then
    if rerr ~= nil and rerr ~= "" then
      return nil, rerr
    end
    return "1" .. id, ""
  end
  return row.key as string, "" -- cast: from any (sqlite row)
end

--- Whether `id`'s own parent chain reaches the board — a real row in
--- `rank_path`, as opposed to one absent entirely (broken, cyclic, or
--- deeper than 16 levels). Unlike `is_ranked`, this says nothing about
--- POSITION: an item can reach the board unpositioned (ordinary
--- triage) and still answer true here.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param id string The item's id
--- @return boolean | nil
--- @return string Error message
local function reaches_board(c: Index, id: string): boolean | nil, string
  local exists, eerr = item_exists(c, id)
  if not exists then
    return nil, absent(eerr, ("read: no such item: %s"):format(id))
  end
  local row, rerr = c.db:query_one("SELECT 1 AS x FROM rank_path WHERE id = ?", {id})
  if row == nil then
    if rerr ~= nil and rerr ~= "" then
      return nil, rerr
    end
    return false, ""
  end
  return true, ""
end

--- The one unified queue: stage first, then rank-path key, then id.
--- The seeded per-session tie-break is policy, applied by `next`.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return {QueueRow} | nil
--- @return string Error message
local function queue(c: Index): {QueueRow} | nil, string
  local rows, err = c.db:query("SELECT id, stage, key FROM queue ORDER BY stage, key, id")
  if rows == nil then
    return nil, err
  end
  local out: {QueueRow} = {}
  for row in rows do
    out[#out + 1] = {
      id = row.id as string, -- cast: from any (sqlite row)
      stage = math.tointeger(row.stage as number) or 0, -- cast: from any (sqlite row)
      key = row.key as string, -- cast: from any (sqlite row)
    }
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The board's positioned open outcomes, rank order, each with whether
--- it already has live work under it.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return {OutcomeRow} | nil
--- @return string Error message
local function outcomes(c: Index): {OutcomeRow} | nil, string
  local rows, err = c.db:query("SELECT id, key, live FROM outcomes ORDER BY key")
  if rows == nil then
    return nil, err
  end
  local out: {OutcomeRow} = {}
  for row in rows do
    out[#out + 1] = {
      id = row.id as string, -- cast: from any (sqlite row)
      key = row.key as string, -- cast: from any (sqlite row)
      live = (math.tointeger(row.live as number) or 0) == 1, -- cast: from any (sqlite row)
    }
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The triage queue: the board's open, unpositioned, childless
--- children, by id.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return {string} | nil Item ids
--- @return string Error message
local function triage(c: Index): {string} | nil, string
  local rows, err = c.db:query("SELECT id FROM triage ORDER BY id")
  if rows == nil then
    return nil, err
  end
  local out: {string} = {}
  for row in rows do
    out[#out + 1] = row.id as string -- cast: from any (sqlite row)
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The count `_work.flow.doing_refusal` compares against `DOING_LIMIT`.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return integer | nil
--- @return string Error message
local function doing_count(c: Index): integer | nil, string
  local row, err = c.db:query_one("SELECT n FROM doing")
  if row == nil then
    return nil, absent(err, "read: doing view returned no row")
  end
  return math.tointeger(row.n as number) or 0, "" -- cast: from any (sqlite row)
end

--- `id`'s children: positioned ones first in position order, then
--- unpositioned ones by id — what a `show ID` children listing reads.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param id string The parent's id
--- @return {ChildRow} | nil
--- @return string Error message
local function children(c: Index, id: string): {ChildRow} | nil, string
  local rows, err = c.db:query([[
    SELECT child, position, open FROM children WHERE parent = ?
    ORDER BY (position IS NULL), position, child
  ]], {id})
  if rows == nil then
    return nil, err
  end
  local out: {ChildRow} = {}
  for row in rows do
    local pos: integer | nil = nil
    if row.position ~= nil then
      pos = math.tointeger(row.position as number) -- cast: from any (sqlite row)
    end
    out[#out + 1] = {
      child = row.child as string, -- cast: from any (sqlite row)
      position = pos,
      open = (math.tointeger(row.open as number) or 0) == 1, -- cast: from any (sqlite row)
    }
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- Every structural finding a whole-board audit can answer with no
--- git object read.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return {StructureRow} | nil
--- @return string Error message
local function structure(c: Index): {StructureRow} | nil, string
  local rows, err = c.db:query("SELECT kind, id, detail FROM structure ORDER BY kind, id")
  if rows == nil then
    return nil, err
  end
  local out: {StructureRow} = {}
  for row in rows do
    out[#out + 1] = {
      kind = row.kind as string, -- cast: from any (sqlite row)
      id = row.id as string, -- cast: from any (sqlite row)
      detail = row.detail as string, -- cast: from any (sqlite row)
    }
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The board's own id — the one parentless item — nil when this board
--- carries none yet (`gitboard init` writes one; `_work.readddl`'s
--- `board` view picks the lowest id on a broken tree carrying more
--- than one, deterministically, the same way `structure`'s
--- `second_root` finding names the rest).
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return string | nil The board's id, nil when there is none
--- @return string Error message
local function board(c: Index): string | nil, string
  local row, err = c.db:query_one("SELECT id FROM board")
  if row == nil then
    if err ~= nil and err ~= "" then
      return nil, err
    end
    return nil, ""
  end
  return row.id as string, "" -- cast: from any (sqlite row)
end

--- Every claim and review claim standing past its lease
--- (`_work.health.LEASE_S`/`REVIEW_LEASE_S`), from `items.touched_at`.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @return {StaleRow} | nil
--- @return string Error message
local function stale(c: Index): {StaleRow} | nil, string
  local rows, err = c.db:query("SELECT id, kind, age_s FROM stale ORDER BY kind, id")
  if rows == nil then
    return nil, err
  end
  local out: {StaleRow} = {}
  for row in rows do
    out[#out + 1] = {
      id = row.id as string, -- cast: from any (sqlite row)
      kind = row.kind as string, -- cast: from any (sqlite row)
      age_s = math.tointeger(row.age_s as number) or 0, -- cast: from any (sqlite row)
    }
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

local record read
  type QueueRow = QueueRow
  type OutcomeRow = OutcomeRow
  type ChildRow = ChildRow
  type StructureRow = StructureRow
  type StaleRow = StaleRow
  role: function(c: Index, id: string): string | nil, string
  state: function(c: Index, id: string): string | nil, string
  substate: function(c: Index, id: string): string | nil, string
  reaches_board: function(c: Index, id: string): boolean | nil, string
  queue: function(c: Index): {QueueRow} | nil, string
  outcomes: function(c: Index): {OutcomeRow} | nil, string
  triage: function(c: Index): {string} | nil, string
  doing_count: function(c: Index): integer | nil, string
  is_ranked: function(c: Index, id: string): boolean | nil, string
  key: function(c: Index, id: string): string | nil, string
  children: function(c: Index, id: string): {ChildRow} | nil, string
  structure: function(c: Index): {StructureRow} | nil, string
  board: function(c: Index): string | nil, string
  stale: function(c: Index): {StaleRow} | nil, string
end

local M: read = {
  role = role,
  state = state,
  substate = substate,
  reaches_board = reaches_board,
  queue = queue,
  outcomes = outcomes,
  triage = triage,
  doing_count = doing_count,
  is_ranked = is_ranked,
  key = key,
  children = children,
  structure = structure,
  board = board,
  stale = stale,
}

return M
