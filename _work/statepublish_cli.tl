--- Native publication CLI. Connector calls are emitted only from immutable plans.
local math = math
local literal = require("_work.singlehead_literal")
local staging = require("_work.statestaging")
local statepublish = require("_work.statepublish")
local plans = require("_work.stateplan")
local refs = require("_work.refs")
local store = require("_work.store")
local gate = require("_work.gitgate")
local function select_one(root: string, selectors: {string}): staging.Receipt | nil, string
  local all, err = staging.list(root)
  if all == nil then return nil, err end
  local matches: {staging.Receipt} = {}
  for _, receipt in ipairs(all) do
    if #receipt.transitions > 0 then
      local matched = #selectors == 0
      for _, selector in ipairs(selectors) do
        if receipt.id:sub(1, #selector) == selector or receipt.ref == selector then matched = true end
      end
      if matched then matches[#matches + 1] = receipt end
    end
  end
  if #matches ~= 1 then return nil, "select exactly one prepared transaction or draft" end
  return matches[1], ""
end
local function cmd_publish(s: store.Store, selectors: {string}, remote: string, execute: boolean,
    plan_path?: string, from_plan?: string, call_index?: string, published_sha?: string,
    repository?: string): integer
  local saved: plans.Plan = nil
  local receipt: staging.Receipt = nil
  if (from_plan or "") ~= "" then
    local loaded, err = plans.load(from_plan)
    if loaded == nil then return gate.verdict_line("publish", false, err) end
    saved = loaded
    local valid, verr = plans.validate_local(s.root, loaded)
    if not valid then return gate.verdict_line("publish", false, verr) end
    if loaded.frozen.remote ~= remote or loaded.frozen.branch ~= "state"
    or loaded.frozen.repository ~= staging.repository(s.root, remote)
    or ((repository or "") ~= "" and repository ~= loaded.frozen.repository) then
      return gate.verdict_line("publish", false, "saved plan destination differs")
    end
  else
    local selected, err = select_one(s.root, selectors)
    if selected == nil then return gate.verdict_line("publish", false, err) end
    if (repository or "") ~= "" and repository ~= selected.repository then
      return gate.verdict_line("publish", false, "prepared repository destination differs")
    end
    local projected, perr = statepublish.build(s.root, selected, remote)
    if projected == nil then return gate.verdict_line("publish", false, perr) end
    local frozen, ferr = staging.snapshot(s.root, selected)
    if frozen == nil then return gate.verdict_line("publish", false, ferr) end
    receipt = frozen
    saved = projected
  end
  if saved == nil then return gate.verdict_line("publish", false, "no saved plan") end
  if (plan_path or "") ~= "" then
    local ok, err = plans.save(plan_path, saved)
    if not ok then return gate.verdict_line("publish", false, err) end
    print(plan_path)
    return gate.verdict_line("publish", true, "frozen publication plan saved; nothing published")
  end
  if (call_index or "") ~= "" then
    if (from_plan or "") == "" then return gate.verdict_line("publish", false, "--call requires --from-plan") end
    local index = math.tointeger(tonumber(call_index))
    if index == nil or index < 0 then return gate.verdict_line("publish", false, "call index must be a nonnegative integer") end
    local call, err = plans.connector_call(saved, index + 1)
    if call == nil then return gate.verdict_line("publish", false, err) end
    local raw, rerr = literal.encode(call)
    if raw == nil then return gate.verdict_line("publish", false, rerr) end
    print(raw)
    return 0
  end
  if (published_sha or "") ~= "" then
    if (from_plan or "") == "" or #published_sha ~= 40 or not published_sha:match("^[0-9a-f]+$") then
      return gate.verdict_line("publish", false, "--published requires --from-plan and a full commit id")
    end
    local all, err = staging.list(s.root)
    if all == nil then return gate.verdict_line("publish", false, err) end
    local recorded = false
    for _, candidate in ipairs(all) do
      if candidate.transaction == saved.frozen.transaction and candidate.tip == saved.frozen.staging_sha
      and candidate.kind == "prepared" then
        candidate.published = published_sha
        local updated, uerr = staging.write(s.root, candidate, candidate.sha)
        if updated == nil then return gate.verdict_line("publish", false, uerr) end
        recorded = true
      end
    end
    if not recorded then return gate.verdict_line("publish", false, "saved attempt receipt is missing") end
    return gate.verdict_line("publish", true, "returned commit recorded; refresh must verify fetched history")
  end
  if execute then
    if receipt == nil then
      return gate.verdict_line("publish", false, "saved plans execute through indexed calls; select the receipt for shell publication")
    end
    local ok, err = statepublish.execute(s.root, receipt)
    if not ok then return gate.verdict_line("publish", false, err) end
    if refs.board_mode(s.root) == "local" then
      local refreshed, rerr = statepublish.sync(s)
      return gate.verdict_line("publish", refreshed, rerr)
    end
    gate.verdict_line("publish", true, err)
    return 2
  end
  if receipt ~= nil then
    print("gitboard publish " .. receipt.id .. " --execute")
  end
  return gate.verdict_line("publish", true, "publication ready; use --plan FILE for a frozen connector plan")
end
local record Module
  cmd_publish: function(s: store.Store, selectors: {string}, remote: string, execute: boolean,
  plan_path?: string, from_plan?: string, call_index?: string, published_sha?: string,
  repository?: string): integer
end
local M: Module = {cmd_publish = cmd_publish}
return M
