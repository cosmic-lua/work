--- Explicit CLI adapter for the experimental connector-backed single-head
--- transport. Native Teal modules own envelope serialization and validation;
--- this module owns checkout binding, exact Git fetch argv, and routing back
--- into gitboard's ordinary prepared/draft confirmation.
local child = require("cosmic.child")
local gate = require("_work.gitgate")
local gitdraft = require("_work.gitdraft")
local gitclaim = require("_work.gitclaim")
local prepared = require("_work.prepared")
local configstore = require("_work.gitsinglehead_config")
local store = require("_work.store")
local transport = require("_work.gittransport")
local binding = require("_work.singlehead_binding")
local calls = require("_work.singlehead_calls")
local hydrate = require("_work.singlehead_hydrate")
local literal = require("_work.singlehead_literal")
local planstore = require("_work.singlehead_plan")
local receipt = require("_work.singlehead_receipts")

local ENVELOPE_PREFIX < const > = "refs/remotes/"

local function run(argv: {string}, cwd: string): string | nil, string
  local r, err = child.run(argv, {cwd = cwd})
  if r == nil then return nil, err end
  if not r.ok then
    local detail = (r.stderr ~= "" and r.stderr or r.stdout):gsub("%s+$", "")
    return nil, detail
  end
  return r.stdout:gsub("%s+$", ""), ""
end

local function config_value(values: {string: string}, key: string): string
  return values[key] or ""
end

local function print_literal(value: any): boolean, string
  local encoded, err = literal.encode(value)
  if encoded == nil then return false, err end
  print(encoded)
  return true, ""
end

local function envelope_ref(config: configstore.Config): string
  return ENVELOPE_PREFIX .. config.remote .. "/" .. config.branch
end

local function exact_head(root: string, config: configstore.Config,
    supplied: string): string | nil, string
  local name = supplied ~= "" and supplied or envelope_ref(config)
  local out, err = run({"git", "rev-parse", "--verify", name .. "^{commit}"}, root)
  if out == nil or out:match("^[0-9a-f]+$") == nil or #out ~= 40 then
    return nil, ("cannot resolve exact envelope head %s: %s"):format(name, err)
  end
  return out, ""
end

local function check_binding(root: string, config: configstore.Config): boolean, string
  local got, err = binding.inspect(root, config.remote, config.repository,
    config.branch)
  return got ~= nil, err
end

local record Candidate
  id: string
  ref: string
  remote: string
  kind: string
  manifest: string
end

local function collect_candidates(root: string): {Candidate} | nil, string
  local found: {Candidate} = {}
  local transactions, terr = prepared.list(root)
  if transactions == nil then return nil, terr end
  for _, tx in ipairs(transactions) do
    local bound_remote = ""
    local kind = "transaction"
    for _, update in ipairs(tx.updates) do
      if update.ref:match("^refs/heads/claim%-batches/") then
        local claim, claim_err = gitclaim.from_transaction(root, tx)
        if claim == nil then return nil, claim_err end
        bound_remote, kind = claim.batch.remote, "claim"
        break
      end
    end
    found[#found + 1] = {id = tx.id, ref = tx.staging_ref,
      remote = bound_remote, kind = kind, manifest = tx.manifest}
  end
  local drafts, derr = gitdraft.list(root)
  if drafts == nil then return nil, derr end
  for _, draft in ipairs(drafts) do
    if #gitdraft.plan(draft) > 0 then
      found[#found + 1] = {id = draft.id, ref = draft.staging_ref,
        remote = draft.remote, kind = "draft", manifest = draft.manifest}
    end
  end
  return found, ""
end

local function select_transaction(root: string, selector: string,
    remote: string): string | nil, string
  local found, candidate_err = collect_candidates(root)
  if found == nil then return nil, candidate_err end
  local matches: {Candidate} = {}
  for _, candidate in ipairs(found) do
    if selector == "" or selector == candidate.ref or selector == candidate.id
    or candidate.id:sub(1, #selector) == selector then
      matches[#matches + 1] = candidate
    end
  end
  if #matches == 0 then
    return nil, selector == "" and "no prepared transaction or non-empty draft"
    or ("no prepared transaction or draft matches %s"):format(selector)
  end
  if #matches > 1 then
    return nil, "select exactly one prepared transaction or draft"
  end
  if matches[1].remote ~= "" and matches[1].remote ~= remote then
    return nil, ("%s %s is bound to remote %s, not %s")
    :format(matches[1].kind, matches[1].id, matches[1].remote, remote)
  end
  return matches[1].ref, ""
end

--- Build a manifest-keyed receipt set. The ordinary confirmation pass re-reads
--- each staging ref and therefore cannot transfer evidence to a replacement.
local function confirmed_receipts(root: string, config: configstore.Config,
    head: string): {string: boolean} | nil, string
  local all, aerr = collect_candidates(root)
  if all == nil then return nil, aerr end
  local receipts: {string: boolean} = {}
  for _, candidate in ipairs(all) do
    if candidate.kind == "claim" or candidate.kind == "draft" then
      local status, rerr = receipt.inspect(root, head, candidate.ref,
        candidate.manifest, config.repository, config.branch)
      if status == nil then return nil, rerr end
      if status.status == "confirmed" then receipts[status.manifest] = true end
    end
  end
  return receipts, ""
end

local function cmd_configure(root: string, values: {string: string}): integer
  local remote = config_value(values, "remote")
  local repository = config_value(values, "repository")
  local branch = config_value(values, "branch")
  if remote == "" or repository == "" or branch == "" then
    return gate.verdict_line("single-head", false,
      "configure requires --remote, --repository, and --branch")
  end
  local probe: configstore.Config = {remote = remote, repository = repository,
    branch = branch}
  local checked, check_err = binding.inspect(root, remote, repository, branch)
  if checked == nil then return gate.verdict_line("single-head", false, check_err) end
  probe.repository, probe.branch = checked.repository, checked.branch
  if configstore.enabled(root) then
    local current, current_err = configstore.read(root)
    if current == nil then
      return gate.verdict_line("single-head", false,
        "REFUSED: active single-head configuration is incomplete: " .. current_err)
    end
    if current.remote ~= probe.remote or current.repository ~= probe.repository
    or current.branch ~= probe.branch then
      return gate.verdict_line("single-head", false,
        "REFUSED: experimental single-head identity is immutable after activation; use a fresh checkout")
    end
    local same_bound, same_err = check_binding(root, current)
    if not same_bound then return gate.verdict_line("single-head", false, same_err) end
    return gate.verdict_line("single-head", true,
      "experimental single-head backend already has this exact binding")
  end
  local staged, stage_err = run({"git", "for-each-ref", "--format=%(refname)",
      "refs/gitboard/prepared", "refs/gitboard/drafts"}, root)
  if staged == nil then return gate.verdict_line("single-head", false, stage_err) end
  if staged ~= "" then
    return gate.verdict_line("single-head", false,
      "REFUSED: configure a fresh checkout before creating prepared transactions or drafts")
  end
  local written, werr = configstore.write(root, probe)
  if not written then return gate.verdict_line("single-head", false, werr) end
  return gate.verdict_line("single-head", true,
    ("EXPERIMENTAL backend configured: remote=%s repository=%s branch=%s; ordinary publish/refresh are now guarded")
    :format(remote, repository, branch))
end

local function cmd_plan(root: string, action: string, selector: string,
    values: {string: string}): integer
  local config, cerr = configstore.read(root)
  if config == nil then return gate.verdict_line("single-head", false, cerr) end
  local bound, berr = check_binding(root, config)
  if not bound then return gate.verdict_line("single-head", false, berr) end
  local out = config_value(values, "out")
  if out == "" then
    return gate.verdict_line("single-head", false,
      action .. " requires --out PLAN.literal for an immutable frozen plan")
  end
  local head, herr = exact_head(root, config, config_value(values, "head"))
  if head == nil then return gate.verdict_line("single-head", false, herr) end
  local plan: planstore.Plan | nil = nil
  local perr = ""
  if action == "publish-plan" then
    local transaction, terr = select_transaction(root, selector, config.remote)
    if transaction == nil then
      return gate.verdict_line("single-head", false, terr)
    end
    plan, perr = planstore.build_transaction(root, root, head, transaction,
      config.repository, config.branch)
  else
    plan, perr = planstore.build_seed(root, root, head,
      "refs/remotes/" .. config.remote .. "/", config.repository, config.branch)
  end
  if plan == nil then return gate.verdict_line("single-head", false, perr) end
  local saved, save_err = planstore.save(out, plan)
  if not saved then return gate.verdict_line("single-head", false, save_err) end
  local summary, sum_err = planstore.summary(plan)
  if summary == nil then return gate.verdict_line("single-head", false, sum_err) end
  local printed, print_err = print_literal(summary)
  if not printed then return gate.verdict_line("single-head", false, print_err) end
  return gate.verdict_line("single-head", true,
    ("frozen %s written to %s at envelope=%s"):format(action, out, head))
end

local function cmd_call(root: string, values: {string: string}): integer
  local config, cerr = configstore.read(root)
  if config == nil then return gate.verdict_line("single-head", false, cerr) end
  local bound, berr = check_binding(root, config)
  if not bound then return gate.verdict_line("single-head", false, berr) end
  local plan, index = config_value(values, "plan"), config_value(values, "call-index")
  if plan == "" or index == "" or index:match("^%d+$") == nil then
    return gate.verdict_line("single-head", false,
      "call requires --plan PLAN.literal and a zero-based --call-index N")
  end
  local frozen, ferr = planstore.load(plan)
  if frozen == nil then return gate.verdict_line("single-head", false, ferr) end
  local bound_calls, bcerr = calls.connector_calls(frozen,
    config.repository, config.branch)
  if bound_calls == nil then return gate.verdict_line("single-head", false, bcerr) end
  local zero_index = math.tointeger(tonumber(index))
  if zero_index == nil then return gate.verdict_line("single-head", false, "invalid call index") end
  local call, call_err = calls.connector_call(frozen, zero_index + 1)
  if call == nil then return gate.verdict_line("single-head", false, call_err) end
  local printed, print_err = print_literal(call)
  if not printed then return gate.verdict_line("single-head", false, print_err) end
  return 0
end

local function fetch_argv(config: configstore.Config): {string}
  return {"git", "fetch", "--atomic", "--no-tags", config.remote,
    ("+refs/heads/%s:%s"):format(config.branch, envelope_ref(config))}
end

local function cmd_refresh(root: string, execute: boolean): integer
  local config, cerr = configstore.read(root)
  if config == nil then return gate.verdict_line("single-head", false, cerr) end
  local bound, berr = check_binding(root, config)
  if not bound then return gate.verdict_line("single-head", false, berr) end
  local fetch = fetch_argv(config)
  if execute then
    local _, ferr = run(fetch, root)
    if ferr ~= "" then return gate.verdict_line("single-head", false, ferr) end
  else
    print(transport.render_argv(fetch))
  end
  local head, herr = exact_head(root, config, "")
  if head == nil then return gate.verdict_line("single-head", false, herr) end
  local projected, hyerr = hydrate.hydrate(root, head,
    "refs/remotes/" .. config.remote .. "/", envelope_ref(config),
    config.repository, config.branch)
  if projected == nil then return gate.verdict_line("single-head", false, hyerr) end
  local printed, print_err = print_literal(projected)
  if not printed then return gate.verdict_line("single-head", false, print_err) end
  local receipts, reterr = confirmed_receipts(root, config, head)
  if receipts == nil then return gate.verdict_line("single-head", false, reterr) end
  local s, serr = store.open(root)
  if s == nil then return gate.verdict_line("single-head", false, serr) end
  return transport.cmd_refresh(s, config.remote, false, true, receipts)
end

local function cmd_single_head(root: string, args: {string},
    values: {string: string}, switches: {string: boolean}): integer
  local action = args[1] or ""
  if action == "configure" then return cmd_configure(root, values) end
  if config_value(values, "remote") ~= ""
  or config_value(values, "repository") ~= ""
  or config_value(values, "branch") ~= "" then
    return gate.verdict_line("single-head", false,
      "binding options are only accepted by single-head configure")
  end
  if action == "seed-plan" or action == "publish-plan" then
    return cmd_plan(root, action, args[2] or "", values)
  end
  if action == "call" then return cmd_call(root, values) end
  if action == "refresh" then
    return cmd_refresh(root, switches["execute"] or false)
  end
  return gate.verdict_line("single-head", false,
    "expected configure, seed-plan, publish-plan, call, or refresh")
end

local record gitsinglehead
  cmd_single_head: function(root: string, args: {string}, values: {string: string},
  switches: {string: boolean}): integer
  fetch_argv: function(config: configstore.Config): {string}
end

local M: gitsinglehead = {
  cmd_single_head = cmd_single_head,
  fetch_argv = fetch_argv,
}

return M
