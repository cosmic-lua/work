--- Replay is confined to a private ref. Source bytes and identities are exact;
--- the existing format-5 subtree is grafted, with only its retired key removed.
local boardtree = require("_work.boardtree")
local claimbatch = require("_work.claimbatch")
local codec = require("cosmic.codec")
local fastimport = require("_work.fastimport")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local gitreadlog = require("_work.gitreadlog")
local itemtree = require("_work.itemtree")
local ksuid = require("cosmic.ksuid")
local source = require("_work.migrate6_source")

local REF < const > = "refs/gitboard/migrate6/replay"
local record Product
  tree: string
  meta: string
  signature: string
  batch: string
end
local record Result
  head: string
  replayed_head: string
  marks: {string: string}
  count: integer
end

--- An item's `meta` without its `claim_batch` line: on one branch the lease is
--- `claims/<id>`, so that key goes away for every replayed item.
--- @param meta string The format-5 meta blob
--- @return string The meta the replay writes
local function stripped(meta: string): string
  local lines: {string} = {}
  for line in (meta .. "\n"):gmatch("([^\n]*)\n") do
    if not line:match("^claim_batch: ") then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

--- One historical item tree as the replay needs it: the grafted subtree, its
--- meta with `claim_batch` stripped, the batch that line named, and a signature
--- that tells a tree-identical event from a real one.
--- @param root string The source repository
--- @param tree string The source commit's tree
--- @return Product | nil The grafted subtree and what it carries
--- @return string Error message
local function product(root: string, tree: string): Product | nil, string
  local got, err = gitobj.cat_file_batch(root, {tree})
  if got == nil or got[tree] == nil then return nil, err or "missing item tree" end
  local entries = gitobj.parse_tree(got[tree].content)
  local meta_sha = ""
  local parts: {string} = {}
  for _, entry in ipairs(entries) do
    if entry.name == "meta" then meta_sha = entry.sha
    else parts[#parts + 1] = entry.mode .. " " .. entry.name .. " " .. entry.sha end
  end
  if meta_sha == "" then return nil, "source item has no meta: " .. tree end
  local blob, berr = gitobj.cat_file_batch(root, {meta_sha})
  if blob == nil or blob[meta_sha] == nil then return nil, berr or "missing meta" end
  local raw = blob[meta_sha].content
  local meta = stripped(raw)
  parts[#parts + 1] = meta
  return {tree = tree, meta = meta, signature = table.concat(parts, "\0"),
    batch = itemtree.parse_meta(raw).claim_batch or ""}, ""
end

--- The `claims/<id>` blob one historical claim batch means for one member, or
--- "" when the lease was dropped. An imported lease keeps its acquisition commit
--- as its identity, so every existing work branch and worktree still matches
--- after the migration.
--- @param root string The source repository
--- @param batch string The claim batch commit the item's meta named
--- @param id string The member's item id
--- @return string | nil The blob content, "" when there is no lease
--- @return string Error message
local function lease(root: string, batch: string, id: string): string | nil, string
  if batch == "" then return "", "" end
  local st, err = claimbatch.read_state(root, batch, id)
  if st == nil then
    if err ~= "" then return nil, err end
    return "", ""
  end
  -- product_base belongs to the product repository; it is never a board mark.
  return boardtree.encode_claim({id = st.root, holder = st.holder,
      acquired_at = st.acquired_at, renewed_at = st.renewed_at,
      expires_at = st.expires_at, product_base = st.product_base})
end

--- One shared fast-import op writing `text` at `path`.
--- @param path string The path to write
--- @param text string Its exact content
--- @return fastimport.Op The shared stream plan op
local function modify(path: string, text: string): fastimport.Op
  return {path = path, content = text}
end

--- One item's `meta` with every `result`, `verdict_head` and `landed_head`
--- naming a replayed commit rewritten through the marks — the evidence rewrite,
--- applied in the final commit so every mark is known by then.
--- @param meta string The replayed meta blob
--- @param marks {string: string} Source commit id -> replayed commit id
--- @return string The meta with its evidence remapped
local function remap_meta(meta: string, marks: {string: string}): string
  local lines: {string} = {}
  for line in (meta .. "\n"):gmatch("([^\n]*)\n") do
    local key, value = line:match("^(%w+_?%w*): (.*)$")
    if (key == "result" or key == "verdict_head" or key == "landed_head")
    and marks[value] ~= nil then line = key .. ": " .. marks[value] end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

--- Numeric Git export marks are joined to the separately retained source
--- order. They are NOT old commit ids and never go directly into the board.
local function parse_marks(raw: string, events: {source.Event}): {string: string} | nil, string
  local out: {string: string} = {}
  local seen: {integer: boolean} = {}
  for line in raw:gmatch("[^\n]+") do
    local number, sha = line:match("^:(%d+) ([0-9a-f]+)$")
    local index = math.tointeger(tonumber(number or ""))
    if index == nil or events[index] == nil or #sha ~= 40 or seen[index] then
      return nil, "invalid Git export-marks"
    end
    out[events[index].sha], seen[index] = sha, true
  end
  for n in ipairs(events) do
    if not seen[n] then return nil, "incomplete Git export-marks" end
  end
  return out, ""
end

--- Replay every source event into one `state` candidate: each item's tree
--- grafted under `items/<id>/`, a claim bridge becoming the `claims/<id>` write
--- its batch means, a tree-identical event materialised as a log path so it is
--- still an event the path walk attributes, and a final commit carrying the
--- marks and the remapped evidence. Builds into a fresh private ref and promotes
--- it under a compare-and-swap, so a retried checkpoint can never rewind a
--- completed candidate to an intermediate tip.
--- @param root string The source repository
--- @param events {source.Event} The merged source order to replay
--- @param workdir string Where the export-marks file is written
--- @param previous Result | nil A completed prior replay to append onto
--- @return Result | nil The candidate head, the marks and the event count
--- @return string Error message
local function replay(root: string, events: {source.Event}, workdir: string,
    previous?: Result, archive?: string): Result | nil, string
  if #events == 0 then return nil, "no item history to migrate" end
  -- Replay into a fresh private ref: a completed prior candidate must never
  -- be rewound to the intermediate history tip when a checkpoint is retried.
  -- Only the completed second stream is promoted, with a local CAS.
  local observed, oerr = source.git(root, {"for-each-ref", "--format=%(objectname)", REF})
  if observed == nil then return nil, oerr end
  local expected = observed:gsub("%s+$", "")
  if expected == "" then expected = ("0"):rep(40) end
  local attempt = ksuid.new()
  local ref = "refs/gitboard/migrate6/attempt-" .. attempt
  local products: {string: Product} = {}
  local current: {string: Product} = {}
  local claims: {string: string} = {}
  local logs: {string: {string: string}} = {}
  local plans: {fastimport.CommitPlan} = {}
  local pending: {source.Event} = {}
  local base = previous and previous.head or ""
  if previous ~= nil then
    for _, event in ipairs(events) do
      if previous.marks[event.sha] ~= nil then
        local p, err = product(root, event.tree)
        if p == nil then return nil, err end
        products[event.tree] = p
        for _, id in ipairs(event.ids or {event.id}) do
          current[id] = p
          local text, cerr = lease(root, p.batch, id)
          if text == nil then return nil, cerr end
          claims[id] = text
        end
      else pending[#pending + 1] = event end
    end
    local entries, err = boardtree.snapshot_entries(root, previous.head)
    if entries == nil then return nil, err end
    local queries: {string} = {}
    for _, entry in ipairs(entries) do
      if entry.path:match("^items/[^/]+/log/[^/]+%.md$") then queries[#queries + 1] = entry.sha end
    end
    local blobs, berr = gitobj.cat_file_batch(root, queries)
    if blobs == nil then return nil, berr end
    for _, entry in ipairs(entries) do
      local id, name = entry.path:match("^items/([^/]+)/log/([^/]+)%.md$")
      if id ~= nil then
        logs[id] = logs[id] or {}
        if blobs[entry.sha] == nil then return nil, "missing accumulated migration log" end
        logs[id][name] = blobs[entry.sha].content
      end
    end
  else pending = events end
  for index, event in ipairs(pending) do
    local p = products[event.tree]
    if p == nil then
      local loaded, err = product(root, event.tree)
      if loaded == nil then return nil, err end
      p, products[event.tree] = loaded, loaded
    end
    local ops: {fastimport.Op} = {}
    for _, member in ipairs(event.ids or {event.id}) do
      local claim_text, cerr = lease(root, p.batch, member)
      if claim_text == nil then return nil, "claim " .. member .. ": " .. cerr end
      local old = current[member]
      local item_logs = logs[member] or {}
      logs[member] = item_logs
      if old ~= nil and old.signature == p.signature
      and (claims[member] or "") == claim_text then
        local entropy = codec.decode_hex(event.sha:sub(1, 32))
        local logid, lerr = ksuid.encode(math.max(1400000000, event.seconds), entropy)
        if logid == nil then return nil, lerr end
        item_logs[logid] = gitreadlog.prose_of(event.message:match("\n\n(.*)$") or "")
      end
      local path = "items/" .. member .. "/"
      ops[#ops + 1] = {path = path:sub(1, -2), tree = p.tree}
      ops[#ops + 1] = modify(path .. "meta", p.meta)
      local names: {string} = {}
      for id in pairs(item_logs) do names[#names + 1] = id end
      table.sort(names)
      for _, id in ipairs(names) do ops[#ops + 1] = modify(path .. "log/" .. id .. ".md", item_logs[id]) end
      if claim_text ~= "" then ops[#ops + 1] = modify("claims/" .. member, claim_text)
      else ops[#ops + 1] = {path = "claims/" .. member, content = nil} end
      current[member], claims[member] = p, claim_text
    end
    if index == 1 and base == "" then ops[#ops + 1] = modify("format", "6\n") end
    plans[#plans + 1] = {ref = ref, mark = ":" .. tostring(index),
      from = index > 1 and (":" .. tostring(index - 1)) or base,
      author_raw = event.author, committer_raw = event.committer,
      message = event.message, verbatim = true, ops = {}}
    plans[#plans].ops = ops
  end
  local marks: {string: string} = {}
  local replayed_head = ""
  local marks_path = ""
  if #pending > 0 then
    marks_path = fs.join(workdir, "git-marks-" .. attempt .. ".tmp")
    local imported, ierr = source.git(root,
      {"fast-import", "--quiet", "--done", "--export-marks=" .. marks_path}, fastimport.build_stream(plans))
    if imported == nil then return nil, ierr end
    local raw, rerr = fs.read(marks_path)
    if raw == nil then return nil, rerr end
    local parsed, merr = parse_marks(raw, pending)
    if parsed == nil then return nil, merr end
    marks = parsed
    replayed_head = marks[pending[#pending].sha]
    if previous ~= nil then
      for old, new in pairs(previous.marks) do marks[old] = new end
    end
    local actual, aerr = source.git(root, {"rev-parse", ref})
    if actual == nil then return nil, aerr end
    if actual:gsub("%s+$", "") ~= replayed_head then return nil, "replay ref did not advance" end
  else
    if previous == nil then return nil, "migration replay has no pending history" end
    marks, replayed_head = previous.marks, previous.replayed_head
  end
  local encoded, eerr = boardtree.encode_marks(marks)
  if encoded == nil then return nil, eerr end
  local final_ops: {fastimport.Op} = {modify("migration/marks", encoded)}
  if archive ~= nil then final_ops[#final_ops + 1] = modify("migration/sources", archive) end
  local ids: {string} = {}
  for id in pairs(current) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    final_ops[#final_ops + 1] = modify("items/" .. id .. "/meta", remap_meta(current[id].meta, marks))
    if claims[id] ~= "" then final_ops[#final_ops + 1] = modify("claims/" .. id, claims[id]) end
  end
  local identity = "gitboard <gitboard@board> " .. tostring(events[#events].seconds) .. " +0000"
  local final: fastimport.CommitPlan = {ref = ref, from = replayed_head,
    author_raw = identity, committer_raw = identity,
    message = "migrate6: preserve marks and remap board evidence\n\nOp: migrate6\n",
    verbatim = true, ops = {}}
  final.ops = final_ops
  local finished, ferr = source.git(root, {"fast-import", "--quiet", "--done"},
    fastimport.build_stream({final}))
  if finished == nil then return nil, ferr end
  local head, herr = source.git(root, {"rev-parse", ref})
  if head == nil then return nil, herr end
  head = head:gsub("%s+$", "")
  local promoted, perr = source.git(root, {"update-ref", REF, head, expected})
  if promoted == nil then return nil, "migration candidate changed during replay: " .. perr end
  local retired, derr = source.git(root, {"update-ref", "-d", ref, head})
  if retired == nil then return nil, derr end
  if marks_path ~= "" then
    local removed, remove_err = fs.remove(marks_path)
    if not removed then return nil, remove_err end
  end
  return {head = head, replayed_head = replayed_head,
    marks = marks, count = #events}, ""
end

local record Replay
  type Result = Result
  replay: function(root: string, events: {source.Event}, workdir: string,
  previous?: Result, archive?: string): Result | nil, string
  remap_meta: function(string, {string: string}): string
  parse_marks: function(string, {source.Event}): {string: string} | nil, string
end
local M: Replay = {replay = replay, remap_meta = remap_meta, parse_marks = parse_marks}
return M
