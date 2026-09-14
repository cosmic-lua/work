--- Minimal composition inspection, final summary, and conflict abandonment.
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local recovery = require("_work.snapshot_recovery")
local refs = require("_work.refs")
local snapshot = require("_work.snapshot")
local snapshot_lock = require("_work.snapshot_lock")
local publication = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")

local function cmd(root: string, summary: string, check_only: boolean,
    abandon: string): integer
  if summary ~= "" and (check_only or abandon ~= "") then
    return gate.verdict_line("snapshot", false, "select only one action")
  end
  local candidate, err = workspace.read(root)
  if candidate == nil then return gate.verdict_line("snapshot", false,
      err ~= "" and err or "no local snapshot") end
  if abandon ~= "" then
    local held, lockerr = snapshot_lock.acquire(root)
    if held == nil then return gate.verdict_line("snapshot", false, lockerr) end
    local _guard < close > = held
    candidate, err = workspace.read(root)
    if candidate == nil then return gate.verdict_line("snapshot", false,
        err ~= "" and err or "no local snapshot") end
    if abandon ~= candidate.commit then return gate.verdict_line("snapshot", false,
        "--abandon must name the current full snapshot commit") end
    local path = workspace.recovery_path(root)
    if fs.is_present(path) then
      local state, lerr = recovery.load(path)
      if state == nil then return gate.verdict_line("snapshot", false, lerr) end
      if state.local_commit ~= candidate.commit then return gate.verdict_line("snapshot", false,
          "a different frozen publication needs reconciliation") end
      local identity, ierr = snapshot.commit_identity(root, candidate.commit)
      if identity == nil then return gate.verdict_line("snapshot", false, ierr) end
      local authored = math.tointeger(tonumber(identity.author.date:match("^(%-?%d+)")))
      local planned, perr = publication.plan(root, candidate.commit,
        refs.board_remote(root), authored)
      if planned == nil then return gate.verdict_line("snapshot", false, perr) end
      local bound, berr = recovery.binding(state, planned.plan)
      if not bound then return gate.verdict_line("snapshot", false, berr) end
      if state.phase ~= "updating" then
        local removed, rerr = recovery.clear(path)
        if not removed then return gate.verdict_line("snapshot", false, rerr) end
        local kept, kerr = workspace.retain_conflict(root, candidate)
        if not kept then return gate.verdict_line("snapshot", false, kerr) end
        return gate.verdict_line("snapshot", true,
          "abandoned snapshot retained at refs/gitboard/conflicts/" .. candidate.commit)
      end
      local head, herr = workspace.canonical_head(root)
      if head == nil then return gate.verdict_line("snapshot", false, herr) end
      local outcome, oerr = recovery.reconcile(root, head, planned.plan, state)
      if outcome == nil then return gate.verdict_line("snapshot", false, oerr) end
      if outcome.status ~= "conflict" then return gate.verdict_line("snapshot", false,
          outcome.status .. ": reconcile or finish publication before abandoning") end
      local removed, rerr = recovery.clear(path)
      if not removed then return gate.verdict_line("snapshot", false, rerr) end
    end
    local kept, kerr = workspace.retain_conflict(root, candidate)
    if not kept then return gate.verdict_line("snapshot", false, kerr) end
    return gate.verdict_line("snapshot", true,
      "conflicted snapshot retained at refs/gitboard/conflicts/" .. candidate.commit)
  end
  if summary ~= "" then
    local commit, serr = workspace.resummary(root, summary)
    if commit == nil then return gate.verdict_line("snapshot", false, serr) end
    print(commit)
    return gate.verdict_line("snapshot", true, "summary set; publish this commit")
  end
  local planned, perr = publication.plan(root, candidate.commit,
    refs.board_remote(root), nil)
  if planned == nil then return gate.verdict_line("snapshot", false, perr) end
  print(candidate.commit .. " " .. publication.compact(planned.report))
  for _, issue in ipairs(planned.report.new_issues) do print("new-spec-issue " .. issue) end
  for _, issue in ipairs(planned.report.existing_issues) do print("existing-spec-issue " .. issue) end
  return gate.verdict_line("snapshot", true,
    check_only and "valid final board" or "local composition; publish this commit")
end

return {cmd = cmd}
