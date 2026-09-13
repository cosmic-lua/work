--- Receipt classification at one exact envelope head. Publication evidence
--- is bound to the pinned staging commit, never its mutable local ref name;
--- live claim authority remains a projection of the current logical refs.
local objects = require("_work.singlehead_objects")
local transaction = require("_work.singlehead_transaction")

local record Status
  status: string
  current: string
  manifest: string
end

local function inspect(root: string, head: string, staging_ref: string,
    expected_manifest: string, repository: string,
    branch: string): Status | nil, string
  local frozen, ferr = transaction.inspect(root, staging_ref, repository, branch)
  if frozen == nil then return nil, ferr end
  if frozen.transaction_sha ~= expected_manifest then
    return nil, "transaction staging ref changed during receipt inspection"
  end
  local state, serr = objects.read_state(root, head, repository, branch)
  if state == nil then return nil, serr end
  local canonical, cerr = objects.canonical({
      transaction_sha = frozen.transaction_sha,
      updates = frozen.updates,
      checks = {},
    })
  if canonical == nil then return nil, cerr end
  local digest = objects.sha256(canonical)
  local observed = state.receipts[frozen.transaction]
  if observed ~= nil and observed ~= digest then
    return nil, "transaction receipt conflicts with staged contents"
  end
  local exact = true
  for _, update in ipairs(frozen.updates) do
    if (state.refs[update.ref] or objects.ZERO) ~= update.next then
      exact = false
      break
    end
  end
  return {status = observed == digest and "confirmed" or "pending",
    current = exact and "exact" or "advanced",
    manifest = frozen.transaction_sha}, ""
end

local record singlehead_receipts
  type Status = Status
  inspect: function(root: string, head: string, staging_ref: string,
  expected_manifest: string, repository: string,
  branch: string): Status | nil, string
end

local M: singlehead_receipts = {inspect = inspect}
return M
