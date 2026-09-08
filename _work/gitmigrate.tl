--- One-hop format-3 to format-4 migration. Format 4 moves claim truth from
--- item metadata/history into immutable shared claim-batch objects, with each
--- item tip carrying a bridge pointer to its batch. Every item ref advances in
--- the same atomic prepared transaction as the format marker: besides making
--- the new representation uniform, this invalidates every unpublished v3 item
--- successor whose old lease might otherwise land after the cutover.
local cache = require("_work.cache")
local child = require("cosmic.child")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local claimsession = require("_work.claimsession")
local format = require("_work.format")
local gitobj = require("_work.gitobj")
local gitread = require("_work.gitread")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local prepared = require("_work.prepared")
local refs = require("_work.refs")

local record Outcome
  current: boolean
  applied: boolean
  transaction: prepared.Transaction | nil
  bridged: integer
  batches: integer
end

local record LegacyClaim
  holder: string
  product_base: string
  root: string
  acquired_at: integer
  renewed_at: integer
  expires_at: integer
end

local function commit_time(root: string, sha: string): integer | nil, string
  local r, err = child.run({"git", "show", "-s", "--format=%ct", sha},
    {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "could not read legacy claim timestamp" end
  local at = math.tointeger(tonumber((r.stdout:gsub("%s+$", ""))))
  if at == nil then return nil, "legacy claim has no valid timestamp" end
  return at, ""
end

local function legacy_claim(root: string, tip: string, holder: string,
    base: string): LegacyClaim | nil, string
  if holder == "" and base == "" then return nil, "" end
  local r, err = child.run({"git", "log", "--first-parent",
      "--format=%H%x09%ct%x09%s", tip}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "could not inspect format-3 claim history" end
  for line in r.stdout:gmatch("([^\n]+)") do
    local sha, stamp, action =
    line:match("^(%x+)\t(%d+)\tclaim ([%a%-]+) %S+ by %S+$")
    if sha ~= nil and (action == "acquire" or action == "force"
      or action == "renew" or action == "drop") then
      local control_at = math.tointeger(tonumber(stamp)) or 0
      local lineage = sha
      if action == "renew" or action == "drop" then
        local body, berr = child.run({"git", "show", "-s", "--format=%B", sha},
          {cwd = root})
        if body == nil then return nil, berr end
        if not body.ok then return nil, "could not read legacy claim control" end
        lineage = body.stdout:match("\nClaim%-Root: ([0-9a-f]+)\n") or ""
        if lineage == "" then return nil, "legacy claim control has no root" end
      end
      local acquired, aerr = commit_time(root, lineage)
      if acquired == nil then return nil, aerr end
      return {holder = holder, product_base = base, root = lineage,
        acquired_at = acquired, renewed_at = control_at,
        expires_at = control_at + claim.LEASE_S}, ""
    end
  end
  local at, terr = commit_time(root, tip)
  if at == nil then return nil, terr end
  return {holder = holder, product_base = base, root = tip,
    acquired_at = at, renewed_at = at, expires_at = at + claim.LEASE_S}, ""
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

local function bridge_commit(root: string, it: item.Item, tip: string,
    at: integer): string | nil, string
  local tree, terr = itemtree.build_tree(root, it,
    gitread.read_spec(root, {tip}), true)
  if tree == nil then return nil, terr end
  local date = ("%d +0000"):format(at)
  return gitobj.commit_tree(root, {tree = tree, parents = {tip},
      message = ("migrate %s to format %s"):format(it.id:sub(-8),
        format.CURRENT), author_name = "gitboard",
      author_email = "gitboard@board", author_date = date,
      committer_name = "gitboard", committer_email = "gitboard@board",
      committer_date = date, op = "migrate"})
end

local function migrate(root: string, now?: integer): Outcome | nil, string
  local state, serr = format.inspect(root)
  if state == nil then return nil, serr end
  local text = (state.content or ""):gsub("%s+$", "")
  if text == format.CURRENT then
    return {current = true, applied = true, transaction = nil,
      bridged = 0, batches = 0}, ""
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
  local remote = refs.board_remote(root)
  local updates: {prepared.Update} = {}
  local batches = 0
  -- The format-4 item decoder deliberately ignores the embedded format-3
  -- claim fields. Read those legacy scalars straight from the frozen tip trees
  -- for this one migration only.
  local meta_queries: {string} = {}
  for _, it in ipairs(board.items) do
    meta_queries[#meta_queries + 1] = board.shas_by_id[it.id] .. ":meta"
  end
  local legacy_meta, lmerr = gitobj.cat_file_batch(root, meta_queries)
  if legacy_meta == nil then return nil, lmerr end
  for _, it in ipairs(board.items) do
    local tip = board.shas_by_id[it.id]
    local target = board.refs_by_id[it.id]
    local meta_entry = legacy_meta[tip .. ":meta"]
    if meta_entry == nil or meta_entry.otype ~= "blob" then
      return nil, ("%s: no readable legacy meta"):format(it.id:sub(-8))
    end
    local meta = itemtree.parse_meta(meta_entry.content)
    local holder = meta.claim or ""
    if holder == "" then holder = meta.reviewer or "" end
    local old, oerr = legacy_claim(root, tip, holder, meta.claim_base or "")
    if oerr ~= "" then return nil, ("%s: %s"):format(it.id:sub(-8), oerr) end
    local batch_sha = ""
    if old ~= nil then
      if old.renewed_at > at + claim.FUTURE_SKEW_S then
        return nil, ("legacy claim on %s has a timestamp more than five minutes "
          .. "in the future; repair the clock/history before migration")
        :format(it.id:sub(-8))
      end
      local active = old.holder ~= "" and at < old.expires_at
      local batch_id = claimsession.mint()
      local made, merr = claimbatch.create(root, {id = batch_id,
          caller = old.holder ~= "" and old.holder or "gitboard-migrate",
          remote = remote, action = "migrate", created_at = at,
          publish_by = 0,
          why = "format-3 claim cutover", rows = {{id = it.id,
              item_tip = tip, operation = active and "hold" or "drop",
              holder = active and old.holder or "",
              product_base = old.product_base, root = old.root,
              acquired_at = old.acquired_at, renewed_at = old.renewed_at,
              expires_at = old.expires_at}}})
      if made == nil then return nil, merr end
      batch_sha = made.commit
      updates[#updates + 1] = {
        ref = "refs/heads/claim-batches/" .. made.id,
        expected = refs.ZERO_SHA, next = made.commit,
      }
      batches = batches + 1
    end
    it.claim, it.reviewer, it.claim_base = "", "", ""
    it.claim_batch = batch_sha
    local next_tip, nerr = bridge_commit(root, it, tip, at)
    if next_tip == nil then return nil, nerr end
    updates[#updates + 1] = {ref = target, expected = tip, next = next_tip}
  end
  local next_format, ferr = format_commit(root, state.sha, at)
  if next_format == nil then return nil, ferr end
  updates[#updates + 1] = {ref = "refs/heads/board/format",
    expected = state.sha, next = next_format}

  local tx, perr = prepared.prepare(root, updates,
    ("migrate board format %s to %s"):format(format.PREVIOUS, format.CURRENT))
  if tx == nil then return nil, perr end
  if refs.board_mode(root) == "remote" then
    return {current = false, applied = false, transaction = tx,
      bridged = #board.items, batches = batches}, ""
  end
  local promoted, proerr = prepared.promote_local(root, tx)
  if not promoted then return nil, proerr end
  local rebuilt, rerr = cache.rebuild(root)
  if rebuilt == nil then
    return nil, ("format migrated, but cache rebuild failed: %s"):format(rerr)
  end
  local closed, cerr = cache.close(rebuilt)
  if not closed then return nil, cerr end
  return {current = false, applied = true, transaction = tx,
    bridged = #board.items, batches = batches}, ""
end

local record gitmigrate
  type Outcome = Outcome
  migrate: function(root: string, now?: integer): Outcome | nil, string
end

local M: gitmigrate = {migrate = migrate}
return M
