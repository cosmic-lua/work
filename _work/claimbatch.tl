--- Immutable shared claim-batch objects. This leaf module owns only their
--- canonical Git representation so item readers and claim writers can both use
--- it without a dependency cycle.
local claim = require("_work.claim")
local gitobj = require("_work.gitobj")

local VERSION < const > = "gitboard-claim-batch-v1"

local record Row
  id: string
  item_tip: string
  operation: string -- acquire | force | hold | renew | drop
  holder: string
  product_base: string
  root: string -- empty means this batch commit for acquire/force
  acquired_at: integer
  renewed_at: integer
  expires_at: integer
end

local record Spec
  id: string
  caller: string
  remote: string
  action: string
  created_at: integer
  publish_by: integer
  why: string
  rows: {Row}
end

local record Batch
  id: string
  commit: string
  caller: string
  remote: string
  action: string
  created_at: integer
  publish_by: integer
  why: string
  rows: {Row}
end

local record Fact
  id: string
  holder: string
  product_base: string
  root: string
  control: string
  acquired_at: integer
  renewed_at: integer
  expires_at: integer
  action: string
end

local function valid_component(value: string): boolean
  return value ~= "" and value:match("^[%w_.%-]+$") ~= nil
end

local function valid_remote(value: string): boolean
  return value ~= "" and value:match("^[%w._/-]+$") ~= nil
  and value:find("..", 1, true) == nil and value:sub(1, 1) ~= "/"
  and value:sub(-1) ~= "/"
end

local function valid_sha(value: string): boolean
  return value ~= nil and #value == 40
  and value:match("^[0-9a-f]+$") ~= nil
end

local function field(value: string): string
  return value == "" and "-" or value
end

local function unfield(value: string): string
  return value == "-" and "" or value
end

local function clean_line(value: string): string
  return ((value or ""):gsub("[%c]+", " "):gsub("^%s+", "")
    :gsub("%s+$", ""))
end

local function encode(spec: Spec): string | nil, string
  if not valid_component(spec.id) or not valid_component(spec.caller)
  or not valid_remote(spec.remote) then
    return nil, "batch, caller, and remote must be safe Git components"
  end
  if spec.created_at <= 0 then return nil, "claim batch needs a positive clock" end
  if #spec.rows == 0 then return nil, "claim batch needs at least one item" end
  local rows: {Row} = {}
  local ids: {string: boolean} = {}
  for _, row in ipairs(spec.rows) do
    if not valid_component(row.id) or ids[row.id] or not valid_sha(row.item_tip) then
      return nil, "claim batch has an invalid or duplicate item row"
    end
    if row.operation ~= "acquire" and row.operation ~= "force"
    and row.operation ~= "hold" and row.operation ~= "renew"
    and row.operation ~= "drop" then
      return nil, "claim batch has an invalid operation"
    end
    if row.holder ~= "" and not valid_component(row.holder) then
      return nil, "claim holder must be a safe component"
    end
    if row.product_base ~= "" and not valid_sha(row.product_base) then
      return nil, "claim product base must be a full commit id"
    end
    if row.root ~= "" and not valid_sha(row.root) then
      return nil, "claim root must be a full commit id"
    end
    ids[row.id] = true
    rows[#rows + 1] = row
  end
  table.sort(rows, function(a: Row, b: Row): boolean return a.id < b.id end)
  local lines: {string} = {
    VERSION,
    "batch " .. spec.id,
    "caller " .. spec.caller,
    "remote " .. spec.remote,
    "action " .. spec.action,
    "created " .. tostring(spec.created_at),
    "publish-by " .. tostring(spec.publish_by),
    "reason " .. field(clean_line(spec.why)),
    "",
  }
  for _, row in ipairs(rows) do
    lines[#lines + 1] = table.concat({row.id, row.item_tip, row.operation,
        field(row.holder), field(row.product_base), field(row.root),
        tostring(row.acquired_at), tostring(row.renewed_at),
        tostring(row.expires_at)}, " ")
  end
  return table.concat(lines, "\n") .. "\n", ""
end

local function decode(content: string, commit: string): Batch | nil, string
  local header, body = content:match("^(.-)\n\n(.*)$")
  if header == nil then return nil, "malformed claim batch manifest" end
  local lines: {string} = {}
  for line in header:gmatch("([^\n]+)") do lines[#lines + 1] = line end
  if lines[1] ~= VERSION then return nil, "not a supported claim batch manifest" end
  local values: {string: string} = {}
  for n = 2, #lines do
    local key, value = lines[n]:match("^(%S+) (.*)$")
    if key == nil or values[key] ~= nil then return nil, "bad claim batch header" end
    values[key] = value
  end
  local created = math.tointeger(tonumber(values.created or ""))
  local publish_by = math.tointeger(tonumber(values["publish-by"] or ""))
  if created == nil or publish_by == nil then return nil, "bad claim batch clock" end
  local rows: {Row} = {}
  for line in body:gmatch("([^\n]+)") do
    local id, item_tip, operation, holder, base, root, acquired, renewed, expires =
    line:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%d+) (%d+) (%d+)$")
    if id == nil then return nil, "bad claim batch row" end
    rows[#rows + 1] = {id = id, item_tip = item_tip, operation = operation,
      holder = unfield(holder), product_base = unfield(base), root = unfield(root),
      acquired_at = math.tointeger(tonumber(acquired)) or 0,
      renewed_at = math.tointeger(tonumber(renewed)) or 0,
      expires_at = math.tointeger(tonumber(expires)) or 0}
  end
  local spec: Spec = {id = values.batch or "", caller = values.caller or "",
    remote = values.remote or "", action = values.action or "",
    created_at = created, publish_by = publish_by,
    why = unfield(values.reason or "-"), rows = rows}
  local canonical, err = encode(spec)
  if canonical == nil then return nil, err end
  if canonical ~= content then return nil, "claim batch manifest is not canonical" end
  return {id = spec.id, commit = commit, caller = spec.caller,
    remote = spec.remote, action = spec.action, created_at = spec.created_at,
    publish_by = spec.publish_by, why = spec.why, rows = spec.rows}, ""
end

local function create(root: string, spec: Spec): Batch | nil, string
  local content, err = encode(spec)
  if content == nil then return nil, err end
  local blob, berr = gitobj.hash_object_write(root, content)
  if blob == nil then return nil, berr end
  local tree, terr = gitobj.mktree_write(root,
    {{mode = "100644", otype = "blob", sha = blob, name = "manifest"}})
  if tree == nil then return nil, terr end
  local date = ("%d +0000"):format(spec.created_at)
  local commit, cerr = gitobj.commit_tree(root, {tree = tree, parents = {},
      message = ("claim batch %s %s by %s"):format(spec.action, spec.id,
        spec.caller), author_name = spec.caller,
      author_email = spec.caller .. "@board", author_date = date,
      committer_name = "gitboard", committer_email = "gitboard@board",
      committer_date = date, op = "claim-batch"})
  if commit == nil then return nil, cerr end
  local batch, derr = decode(content, commit)
  if batch == nil then return nil, derr end
  -- Acquisition roots are the immutable batch object itself; encoding them as
  -- empty avoids a self-hash cycle.
  for _, row in ipairs(batch.rows) do
    if (row.operation == "acquire" or row.operation == "force")
    and row.root == "" then row.root = commit end
  end
  return batch, ""
end

local function read(root: string, commit: string): Batch | nil, string
  if not valid_sha(commit) then return nil, "claim batch needs a full commit id" end
  local got, err = gitobj.cat_file_batch(root, {commit, commit .. ":manifest"})
  if got == nil then return nil, err end
  local object, manifest = got[commit], got[commit .. ":manifest"]
  if object == nil or object.otype ~= "commit"
  or manifest == nil or manifest.otype ~= "blob" then
    return nil, "unreadable claim batch object"
  end
  local batch, derr = decode(manifest.content, commit)
  if batch == nil then return nil, derr end
  for _, row in ipairs(batch.rows) do
    if (row.operation == "acquire" or row.operation == "force")
    and row.root == "" then row.root = commit end
  end
  return batch, ""
end

local function read_fact(root: string, commit: string, id: string): Fact | nil, string
  if commit == "" then return nil, "" end
  local batch, err = read(root, commit)
  if batch == nil then return nil, err end
  for _, row in ipairs(batch.rows) do
    if row.id == id then
      return {id = id, holder = row.holder, product_base = row.product_base,
        root = row.root, control = commit, acquired_at = row.acquired_at,
        renewed_at = row.renewed_at, expires_at = row.expires_at,
        action = row.operation}, ""
    end
  end
  return nil, "claim batch does not contain item " .. id
end

local function read_state(root: string, commit: string,
    id: string): claim.State | nil, string
  local fact, err = read_fact(root, commit, id)
  if fact == nil then return nil, err end
  if fact.holder == "" then return nil, "" end
  return {holder = fact.holder, root = fact.root, control = fact.control,
    acquired_at = fact.acquired_at, renewed_at = fact.renewed_at,
    expires_at = fact.expires_at, product_base = fact.product_base}, ""
end

local record claimbatch
  type Row = Row
  type Spec = Spec
  type Batch = Batch
  type Fact = Fact
  create: function(root: string, spec: Spec): Batch | nil, string
  read: function(root: string, commit: string): Batch | nil, string
  read_fact: function(root: string, commit: string, id: string): Fact | nil, string
  read_state: function(root: string, commit: string, id: string): claim.State | nil, string
end

local M: claimbatch = {create = create, read = read, read_fact = read_fact,
  read_state = read_state}

return M
