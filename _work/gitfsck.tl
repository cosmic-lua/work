--- `fsck`: a read-only, offline whole-board audit — the problems no
--- other verb ever asks about because nothing else asks a WHOLE-board
--- question. `docs/design/read.md`'s "The one verb that reads git": the
--- database at `o/board.db` is the read model every other verb reads,
--- rebuilt from the refs on a digest mismatch and patched by every
--- save — `fsck` is the one place that reads git to check that model
--- AGAINST the refs it claims to derive from, rebuilding the same
--- rows into a throwaway database (`_work.cacherebuild.fill`'s own
--- fill path, reused against `:memory:`) and diffing every `items`
--- row (lease columns included), every `ranks` row, and the `events`
--- count per item against the session's own open cache.
---
--- Structural findings — a dangling `parent`, a second parentless item
--- (there is meant to be exactly one — the board), an `order` entry
--- naming an id that is not a child of the item carrying it, two open
--- items sharing a `key`, and a parent chain broken, cyclic, or deeper
--- than 16 levels — are `_work.read.structure`'s five SQL-derivable
--- kinds, asked of the same throwaway rebuild. An `order` entry naming
--- a non-child is reported but never counted: a read that walks
--- `_work.read.children` skips straight past it, so it is not a
--- problem any read ever meets — see "stale order entries" below.
---
--- What SQL cannot answer, this module still asks directly: an item's
--- tree not re-encoding to what it was read from (a hand edit, a
--- canonical form that drifted — `tree_problem`), an id filed under
--- both `refs/heads/items` and `refs/heads/ended` at once (the residue
--- of a resolution whose atomic push landed the create half of an
--- old-style namespace move and lost the delete half — the pushing
--- credential can create and update a branch but never delete one),
--- a stray branch under the item namespaces whose tail is not a
--- KSUID, and the stale `refs/heads/board/lanes` ref no build writes
--- any more. `store.list`'s own format check (`_work.gitread`) is the
--- board-readable precondition every other check here depends on — a
--- board this tool cannot even read is reported as the one problem it
--- is, nothing else asked.
local cacherebuild = require("_work.cacherebuild")
local gate = require("_work.gitgate")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local index = require("_work.index")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local read = require("_work.read")
local refs = require("_work.refs")
local sqlite = require("cosmic.sqlite")
local store = require("_work.store")
local tail = require("_work.tail")

--- `items` columns worth comparing between the session's cache and the
--- throwaway rebuild — every column but `id` itself, which is the key
--- the comparison is keyed on.
local ITEM_COLUMNS < const >: {string} = {
  "title", "parent", "repo", "base", "key", "claim", "reviewer", "pr",
  "result", "verdict", "verdict_head", "verdict_spec", "resolution",
  "ref", "tip", "touched_at",
}

--- Whether one item's tree, re-encoded from its own decoded fields,
--- hashes IDENTICALLY to the tip it was read from — the canonical
--- round trip `_work/itemtree_test.tl` tests for one item, asked here
--- of every item on the board. nil when the item carries no observed
--- lease at all (unreachable through `store.list`, kept only so this
--- stays total). `itemtree.build_tree` here is the pure, non-writing
--- form (no `write` argument) — this is a read-only audit, so nothing
--- it computes needs to actually exist in the odb, only to hash the
--- same as what is already there.
--- @param s store.Store The store
--- @param it item.Item The item
--- @param spec_body string Its spec sidecar, "" when it has none
--- @param observed_trees {string: string} Every observed commit sha
--- (`s.leased_sha`) mapped to its tree sha, from ONE
--- `gitobj.tree_of_batch` call over the whole board
--- @return string | nil The problem
local function tree_problem(s: store.Store, it: item.Item, spec_body: string,
    observed_trees: {string: string}): string
  local observed_sha = s.leased_sha[it.id]
  if observed_sha == nil or observed_sha == "" then
    return nil
  end
  local observed_tree = observed_trees[observed_sha]
  if observed_tree == nil then
    return ("%s: could not read its observed tree"):format(it.id:sub(1, 8))
  end
  local rebuilt, berr = itemtree.build_tree(s.root, it, spec_body)
  if rebuilt == nil then
    return ("%s: could not re-encode its tree: %s"):format(it.id:sub(1, 8), berr)
  end
  if rebuilt ~= observed_tree then
    return ("%s: does not re-encode to the tree it was read from (%s vs %s) — "
      .. "canonical form drifted"):format(it.id:sub(1, 8), rebuilt:sub(1, 7),
      observed_tree:sub(1, 7))
  end
  return nil
end

--- The stale `refs/heads/board/lanes` finding: nothing writes it any more —
--- the lane observation lives in the cache database instead — but a
--- board carried over from before that move may still have one.
--- @param s store.Store The store
--- @return string | nil The problem, nil when the ref is not there
local function stale_lanes_ref_problem(s: store.Store): string | nil
  local found = refs.for_each_ref(s.root, {"refs/heads/board/lanes"})
  if found ~= nil and #found > 0 then
    return "refs/heads/board/lanes: stale — lane observations now live in "
    .. "the cache database (o/board.db), not a committed ref; delete it"
  end
  return nil
end

--- Branches under the item namespaces whose tail is not a KSUID: not
--- items, skipped by every read, and worth deleting.
--- @param s store.Store The store
--- @return {string} One line per stray ref
local function stray_ref_problems(s: store.Store): {string}
  local out: {string} = {}
  local found = refs.for_each_ref(s.root, {"refs/heads/items", "refs/heads/ended"})
  for _, r in ipairs(found or {}) do
    local tail_seg = r.refname:match("/([^/]+)$") or ""
    if not (#tail_seg == 27 and tail_seg:match("^%w+$")) then
      out[#out + 1] = ("stray ref %s: not an item id; delete the branch"):format(r.refname)
    end
  end
  return out
end

--- One line per id `list` found filed under both `refs/heads/items`
--- and `refs/heads/ended` at once, naming which ref is being read and
--- the exact command a credential with delete rights runs to clear
--- the other — the push every ordinary session makes can create and
--- update a branch but never delete one, so this repair needs a
--- different credential.
--- @param s store.Store The store, after a `list` call
--- @return {string} One line per duplicate, possibly empty
local function duplicate_ref_problems(s: store.Store): {string}
  local out: {string} = {}
  for _, d in ipairs(store.duplicates(s)) do
    out[#out + 1] = ("%s: filed under both %s and %s — reading %s; clear the other "
      .. "with `git push origin --delete %s`"):format(
      d.id:sub(1, 8), d.kept_ref, d.dropped_ref, d.kept_ref, d.dropped_ref)
  end
  return out
end

--- Every `items` row, keyed by id, every column but `id` stringified —
--- the shape `audit_cache` diffs.
--- @param db sqlite.Database The connection
--- @return {string: {string: string}} | nil id -> column -> value
--- @return string Error message
local function read_items(db: sqlite.Database): {string: {string: string}} | nil, string
  local rows, err = db:query("SELECT * FROM items")
  if rows == nil then
    return nil, err
  end
  local out: {string: {string: string}} = {}
  for row in rows do
    local id = row.id as string -- cast: from any (sqlite row)
    local cols: {string: string} = {}
    for _, col in ipairs(ITEM_COLUMNS) do
      cols[col] = tostring(row[col])
    end
    out[id] = cols
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- Every `ranks` row, grouped by parent, in stored position order —
--- the whole ordered child list is what `audit_cache` diffs, since the
--- ORDER is exactly the fact under audit.
--- @param db sqlite.Database The connection
--- @return {string: {string}} | nil parent -> ordered child ids
--- @return string Error message
local function read_ranks(db: sqlite.Database): {string: {string}} | nil, string
  local rows, err = db:query("SELECT parent, child FROM ranks ORDER BY parent, position")
  if rows == nil then
    return nil, err
  end
  local out: {string: {string}} = {}
  for row in rows do
    local parent = row.parent as string -- cast: from any (sqlite row)
    local child = row.child as string -- cast: from any (sqlite row)
    out[parent] = out[parent] or {}
    local list = out[parent]
    list[#list + 1] = child
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- Every item's `events` row count.
--- @param db sqlite.Database The connection
--- @return {string: integer} | nil item id -> row count
--- @return string Error message
local function read_event_counts(db: sqlite.Database): {string: integer} | nil, string
  local rows, err = db:query("SELECT item, COUNT(*) AS n FROM events GROUP BY item")
  if rows == nil then
    return nil, err
  end
  local out: {string: integer} = {}
  for row in rows do
    out[row.item as string] = math.tointeger(row.n as number) or 0 -- cast: from any (sqlite row)
  end
  local rerr = rows:err()
  if rerr then
    return nil, rerr
  end
  return out, ""
end

--- The audit `fsck` exists to run: every `items` row (lease columns
--- included), every `ranks` row, and the `events` count per item,
--- between the throwaway rebuild (`refs_db`, freshly filled from what
--- git says right now) and the session's own open cache (`cache_db`,
--- `o/board.db`). One finding line per disagreement,
--- `cache: <handle> <column> reads X, refs say Y` — named for the
--- cache since the refs are truth and the cache is the read model
--- derived from them.
--- @param refs_db sqlite.Database The throwaway rebuild
--- @param cache_db sqlite.Database The session's open cache
--- @return {string} One line per disagreement
--- @return string Error message
local function audit_cache(refs_db: sqlite.Database, cache_db: sqlite.Database): {string}, string
  local refs_items, rierr = read_items(refs_db)
  if refs_items == nil then
    return {}, rierr
  end
  local cache_items, cierr = read_items(cache_db)
  if cache_items == nil then
    return {}, cierr
  end
  local refs_ranks, rrerr = read_ranks(refs_db)
  if refs_ranks == nil then
    return {}, rrerr
  end
  local cache_ranks, crerr = read_ranks(cache_db)
  if cache_ranks == nil then
    return {}, crerr
  end
  local refs_events, reerr = read_event_counts(refs_db)
  if refs_events == nil then
    return {}, reerr
  end
  local cache_events, ceerr = read_event_counts(cache_db)
  if cache_events == nil then
    return {}, ceerr
  end

  local ids: {string} = {}
  local seen: {string: boolean} = {}
  for id in pairs(refs_items) do
    seen[id] = true
    ids[#ids + 1] = id
  end
  for id in pairs(cache_items) do
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)

  local out: {string} = {}
  for _, id in ipairs(ids) do
    local want = refs_items[id]
    local got = cache_items[id]
    if want == nil then
      out[#out + 1] = ("cache: %s is in the cache but not in the refs"):format(tail.handle(id))
    elseif got == nil then
      out[#out + 1] = ("cache: %s is in the refs but not in the cache"):format(tail.handle(id))
    else
      for _, col in ipairs(ITEM_COLUMNS) do
        if got[col] ~= want[col] then
          out[#out + 1] = ("cache: %s %s reads %s, refs say %s"):format(
            tail.handle(id), col, got[col], want[col])
        end
      end
    end
    local want_n = refs_events[id] or 0
    local got_n = cache_events[id] or 0
    if want_n ~= got_n then
      out[#out + 1] = ("cache: %s events reads %d, refs say %d"):format(
        tail.handle(id), got_n, want_n)
    end
    local want_order = table.concat(refs_ranks[id] or {}, ",")
    local got_order = table.concat(cache_ranks[id] or {}, ",")
    if want_order ~= got_order then
      out[#out + 1] = ("cache: %s order reads [%s], refs say [%s]"):format(
        tail.handle(id), got_order, want_order)
    end
  end
  return out, ""
end

--- The `ok` verdict detail: item count alone when nothing was ignored,
--- with the stale-order count appended only when there is one — the
--- common healthy-board case stays exactly as terse as it always was.
--- @param n_items integer How many items the board carries
--- @param n_stale integer How many stale order entries were found
--- @return string
local function ok_detail(n_items: integer, n_stale: integer): string
  if n_stale > 0 then
    return ("ok (%d items), %d stale order entries"):format(n_items, n_stale)
  end
  return ("ok (%d items)"):format(n_items)
end

--- The failing verdict detail: the problem count, with the stale-order
--- count appended only when there is one.
--- @param n_problems integer How many real problems were found
--- @param n_stale integer How many stale order entries were found
--- @return string
local function fail_detail(n_problems: integer, n_stale: integer): string
  if n_stale > 0 then
    return ("%d problem(s), %d stale order entries"):format(n_problems, n_stale)
  end
  return ("%d problem(s)"):format(n_problems)
end

local function cmd_fsck(s: store.Store): integer
  -- A fresh git read, never the cache-backed `store.list`: this audit's
  -- own job is checking the database against git, so it needs to
  -- rebuild the derived rows from the refs itself rather than trust
  -- whatever `o/board.db` already holds.
  local board, lerr = gitread.list(s.root)
  if board == nil then
    print(lerr)
    return gate.verdict_line("fsck", false, "1 problem(s)")
  end
  local all = board.items
  for id, sha in pairs(board.shas_by_id) do
    s.leased_sha[id] = sha
  end
  s.duplicates = board.duplicates
  local ids: {string} = {}
  local observed_shas: {string} = {}
  for _, it in ipairs(all) do
    ids[#ids + 1] = it.id
    local sha = s.leased_sha[it.id]
    if sha ~= nil and sha ~= "" then
      observed_shas[#observed_shas + 1] = sha
    end
  end
  local specs = store.read_specs(s, ids)

  local problems: {string} = {}
  local stale_orders: {string} = {}

  -- Rebuild the derived rows from the refs into a throwaway in-memory
  -- database, reusing `_work.cacherebuild`'s own fill path — the same
  -- schema and data `store.read` incrementally maintains at
  -- `o/board.db`, built fresh from what git says right now.
  local mem, merr = sqlite.open(":memory:")
  if mem == nil then
    problems[#problems + 1] = ("could not open a throwaway database: %s"):format(merr)
  else
    local fok, ferr = cacherebuild.fill(mem, s.root, board, specs)
    if not fok then
      problems[#problems + 1] = ("could not rebuild the throwaway database: %s"):format(ferr)
      local _c, _cerr = mem:close()
      mem = nil
    end
  end

  if mem ~= nil then
    local rebuilt: index.Index = {db = mem, specs = specs, load_problems = {}}
    -- `read.structure`'s five SQL-derivable findings, asked of the
    -- fresh rebuild — what a Teal walk over `all` used to compute by
    -- hand. `stale_order` is reported but never counted: a read that
    -- walks `_work.read.children` skips straight past it, so it is
    -- not a problem any read ever meets.
    local srows, serr = read.structure(rebuilt)
    if srows == nil then
      problems[#problems + 1] = ("could not query structure: %s"):format(serr)
    else
      for _, r in ipairs(srows) do
        local line = ("%s: %s"):format(r.id:sub(1, 8), r.detail)
        if r.kind == "stale_order" then
          stale_orders[#stale_orders + 1] = line
        else
          problems[#problems + 1] = line
        end
      end
    end

    -- The audit itself: the session's own open cache, diffed against
    -- the fresh rebuild row by row — one line per disagreement, or a
    -- single confirming line when there is none.
    local c, cerr = store.read(s)
    if c == nil then
      problems[#problems + 1] = ("could not open the session cache: %s"):format(cerr)
    else
      local diffs, derr = audit_cache(mem, c.db)
      if derr ~= "" then
        problems[#problems + 1] = ("could not audit the cache: %s"):format(derr)
      elseif #diffs == 0 then
        print("gitboard-fsck: cache agrees with the refs")
      end
      for _, d in ipairs(diffs) do
        problems[#problems + 1] = d
      end
    end
    local _c, _cerr = mem:close()
  end

  -- One process for every item's observed tree, whatever the board's
  -- size — the batched form of `gitobj.tree_of`, which used to cost
  -- one `git rev-parse` PER item here.
  local observed_trees, terr = gitobj.tree_of_batch(s.root, observed_shas)
  if observed_trees == nil then
    problems[#problems + 1] = ("could not read observed trees: %s"):format(terr)
    observed_trees = {}
  end
  for _, it in ipairs(all) do
    local p = tree_problem(s, it, specs[it.id] or "", observed_trees)
    if p ~= nil then
      problems[#problems + 1] = p
    end
  end
  local lanes_p = stale_lanes_ref_problem(s)
  if lanes_p ~= nil then
    problems[#problems + 1] = lanes_p
  end
  for _, p in ipairs(duplicate_ref_problems(s)) do
    problems[#problems + 1] = p
  end
  for _, p in ipairs(stray_ref_problems(s)) do
    problems[#problems + 1] = p
  end

  for _, p in ipairs(problems) do
    print(p)
  end
  if #stale_orders > 0 then
    print("stale order entries (ignored by reads):")
    for _, p in ipairs(stale_orders) do
      print(p)
    end
  end
  if #problems == 0 then
    return gate.verdict_line("fsck", true, ok_detail(#all, #stale_orders))
  end
  return gate.verdict_line("fsck", false, fail_detail(#problems, #stale_orders))
end

local record gitfsck
  cmd_fsck: function(s: store.Store): integer
end

local M: gitfsck = {
  cmd_fsck = cmd_fsck,
}

return M
