--- Frozen connector calls for the single-head envelope transport.  These
--- records are also the on-disk plan schema: every provider argument is kept
--- inline and the only symbolic values are prior call result SHAs.
local objects = require("_work.singlehead_objects")
local literal_codec = require("_work.singlehead_literal")

local PLAN_FORMAT < const > = "gitboard-single-head-plan-v2"
local TREE_CALL_BYTES < const > = 256 * 1024

local type TreeElement = objects.TreeElement

local record Guard
  publish_by: integer
  rule: string
end

local record Call
  id: string
  tool: string
  arguments: {string: any}
  guard: Guard | nil
end

local record Plan
  plan_format: string
  status: string
  expected_head: string
  head: string
  repository: string
  branch: string
  transaction: string
  transaction_sha: string
  receipt_digest: string
  source: {string: any}
  publish_by: integer
  base_tree_sha: string
  tree_elements: {TreeElement}
  message: string
  calls: {Call}
end

local function render(plan: Plan): {Call} | nil, string
  local calls: {Call} = {}
  if plan.status ~= "ready" then return calls, "" end
  local group: {TreeElement} = {}
  local size, base = 0, plan.base_tree_sha
  local function flush()
    local id = "create_tree_" .. tostring(#calls + 1)
    local inline: {{string: any}} = {}
    for _, entry in ipairs(group) do
      inline[#inline + 1] = {path = entry.path, mode = entry.mode,
        type = entry.otype, content = entry.content}
    end
    calls[#calls + 1] = {id = id, tool = "github_create_tree", guard = nil,
      arguments = {repository_full_name = plan.repository,
        base_tree_sha = base, tree_elements = inline}}
    base, group, size = "$" .. id .. ".sha", {}, 0
  end
  for _, entry in ipairs(plan.tree_elements) do
    local wire = {path = entry.path, mode = entry.mode,
      type = entry.otype, content = entry.content}
    local encoded, err = objects.canonical(wire)
    if encoded == nil then return nil, err end
    local weight = #encoded
    if weight > TREE_CALL_BYTES then
      return nil, "one tree entry exceeds the connector upload budget"
    end
    if #group > 0 and size + weight > TREE_CALL_BYTES then flush() end
    group[#group + 1], size = entry, size + weight
  end
  if #group > 0 then flush() end
  if #calls == 0 then return nil, "ready plan has no tree entries" end
  calls[#calls + 1] = {id = "create_commit", tool = "github_create_commit",
    guard = nil, arguments = {repository_full_name = plan.repository,
      parent_sha = plan.expected_head, tree_sha = base, message = plan.message}}
  calls[#calls + 1] = {id = "", tool = "github_update_ref",
    guard = {publish_by = plan.publish_by,
      rule = "if nonzero, current time must be strictly before deadline"},
    arguments = {repository_full_name = plan.repository,
      branch_name = plan.branch, sha = "$create_commit.sha", force = false}}
  return calls, ""
end

--- Literal-facing value for a plan. `otype` is an internal Git object field;
--- GitHub's create-tree schema spells it `type`.
local function wire_value(plan: Plan): {string: any}
  local elements = literal_codec.sequence() as {{string: any}} -- cast: empty wire sequence
  for _, entry in ipairs(plan.tree_elements) do
    elements[#elements + 1] = {path = entry.path, mode = entry.mode,
      type = entry.otype, content = entry.content}
  end
  local rendered = literal_codec.sequence() as {Call} -- cast: empty wire sequence
  for _, call in ipairs(plan.calls) do rendered[#rendered + 1] = call end
  return {plan_format = plan.plan_format, status = plan.status,
    expected_head = plan.expected_head, head = plan.head,
    repository = plan.repository, branch = plan.branch,
    transaction = plan.transaction, transaction_sha = plan.transaction_sha,
    receipt_digest = plan.receipt_digest, source = plan.source,
    publish_by = plan.publish_by, base_tree_sha = plan.base_tree_sha,
    tree_elements = elements, message = plan.message, calls = rendered}
end

local function same_entries(a: {TreeElement}, b: {TreeElement}): boolean
  if #a ~= #b then return false end
  for i = 1, #a do
    local x, y = a[i], b[i]
    if x.path ~= y.path or x.mode ~= y.mode or x.otype ~= y.otype
    or x.content ~= y.content then return false end
  end
  return true
end

local function validate(plan: Plan): boolean, string
  if plan.plan_format ~= PLAN_FORMAT then return false, "unsupported saved plan format" end
  local repository, rerr = objects.checked_repository(plan.repository)
  if repository == nil or repository ~= plan.repository then
    return false, rerr ~= "" and rerr or "saved plan repository is not canonical"
  end
  local branch, berr = objects.checked_branch(plan.branch)
  if branch == nil or branch ~= plan.branch then return false, berr end
  local txsha, terr = objects.checked_sha(plan.transaction_sha, false)
  if txsha == nil then return false, terr end
  if #plan.transaction < 1 or #plan.transaction > 160
  or plan.transaction:match("^[A-Za-z0-9_-]+$") == nil
  or #plan.receipt_digest ~= 64
  or plan.receipt_digest:match("^[0-9a-f]+$") == nil then
    return false, "invalid saved plan transaction binding"
  end
  if plan.status == "confirmed" then
    if plan.head == "" then return false, "confirmed plan lacks observed head" end
    local _, herr = objects.checked_sha(plan.head, false)
    if herr ~= "" then return false, herr end
    if #plan.calls ~= 0 or #plan.tree_elements ~= 0 then
      return false, "confirmed plan contains publication calls"
    end
    return true, ""
  end
  if plan.status ~= "ready" then return false, "invalid saved plan status" end
  local _, herr = objects.checked_sha(plan.expected_head, false)
  if herr ~= "" then return false, herr end
  local _, treeerr = objects.checked_sha(plan.base_tree_sha, false)
  if treeerr ~= "" then return false, treeerr end
  if plan.publish_by < 0 then return false, "invalid saved plan deadline" end
  local expected, cerr = render(plan)
  if expected == nil then return false, cerr end
  if #expected ~= #plan.calls then return false, "saved plan has invalid connector calls" end
  for i = 1, #expected do
    local want, got = expected[i], plan.calls[i]
    local wa, ga = objects.canonical(want.arguments), objects.canonical(got.arguments)
    if got.id ~= want.id or got.tool ~= want.tool or wa ~= ga then
      return false, "saved plan publication chain is malformed"
    end
    local wg, gg = objects.canonical(want.guard), objects.canonical(got.guard)
    if wg ~= gg then return false, "saved plan deadline guard is malformed" end
  end
  local entries: {TreeElement} = {}
  for i = 1, #plan.calls - 2 do
    local raw = plan.calls[i].arguments.tree_elements
    if not (raw is {any}) then return false, "saved plan tree call is malformed" end
    for _, value in ipairs(raw) do
      if not (value is {string: any}) then return false, "saved plan tree entry is malformed" end
      local path, mode, otype, content = value.path, value.mode, value["type"], value.content
      if not (path is string and mode is string and otype is string and content is string) then
        return false, "saved plan tree entry is malformed"
      end
      entries[#entries + 1] = {path = path, mode = mode, otype = otype, content = content}
    end
  end
  if not same_entries(entries, plan.tree_elements) then
    return false, "saved plan calls differ from its frozen tree"
  end
  return true, ""
end

local function connector_calls(plan: Plan, repository?: string,
    branch?: string): {Call} | nil, string
  local ok, err = validate(plan)
  if not ok then return nil, err end
  if repository ~= nil then
    local canonical, rerr = objects.checked_repository(repository)
    if canonical == nil then return nil, rerr end
    if canonical ~= plan.repository then return nil, "connector repository differs from saved plan" end
  end
  if branch ~= nil then
    local canonical, berr = objects.checked_branch(branch)
    if canonical == nil then return nil, berr end
    if canonical ~= plan.branch then return nil, "connector branch differs from saved plan" end
  end
  -- A safe literal round trip prevents a caller from mutating the sealed plan
  -- table. The parser accepts literals only; it never loads or executes code.
  local raw, ferr = literal_codec.encode(plan.calls)
  if raw == nil then return nil, ferr end
  local copied, perr = literal_codec.decode(raw)
  if copied == nil or not (copied is {any}) then
    return nil, perr ~= "" and perr or "connector calls are not a sequence"
  end
  return copied as {Call}, "" -- cast: just formatted Call records
end

--- Indexes are one-based, matching the CLI call number and Lua arrays.
local function connector_call(plan: Plan, index: integer,
    now?: integer): Call | nil, string
  local calls, err = connector_calls(plan)
  if calls == nil then return nil, err end
  if index < 1 or index > #calls then return nil, "call index outside plan" end
  local call = calls[index]
  if call.tool == "github_update_ref" and plan.publish_by > 0
  and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim batch expired before publication"
  end
  -- The guard is execution metadata, not a GitHub connector argument. The
  -- caller receives the same {id, tool, arguments} shape for every step.
  call.guard = nil
  return call, ""
end

local record singlehead_calls
  PLAN_FORMAT: string
  TREE_CALL_BYTES: integer
  type TreeElement = TreeElement
  type Guard = Guard
  type Call = Call
  type Plan = Plan
  render: function(plan: Plan): {Call} | nil, string
  wire_value: function(plan: Plan): {string: any}
  validate: function(plan: Plan): boolean, string
  connector_calls: function(plan: Plan, repository?: string,
  branch?: string): {Call} | nil, string
  connector_call: function(plan: Plan, index: integer,
  now?: integer): Call | nil, string
end

local M: singlehead_calls = {PLAN_FORMAT = PLAN_FORMAT,
  TREE_CALL_BYTES = TREE_CALL_BYTES, render = render, wire_value = wire_value,
  validate = validate,
  connector_calls = connector_calls, connector_call = connector_call}
return M
