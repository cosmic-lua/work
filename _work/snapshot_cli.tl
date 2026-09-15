--- Minimal composition inspection, final summary, and conflict abandonment.
local gate = require("_work.gitgate")
local refs = require("_work.refs")
local publication = require("_work.snapshot_publish")
local workspace = require("_work.snapshot_workspace")

local function cmd(root: string, summary: string, check_only: boolean,
    abandon: string): integer
  if summary ~= "" and (check_only or abandon ~= "") then
    return gate.verdict_line("snapshot", false, "select only one action")
  end
  if abandon ~= "" then
    local ok, detail = publication.abandon(root, abandon)
    return gate.verdict_line("snapshot", ok, detail)
  end
  local candidate, err = workspace.read(root)
  if candidate == nil then return gate.verdict_line("snapshot", false,
      err ~= "" and err or "no local snapshot") end
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
