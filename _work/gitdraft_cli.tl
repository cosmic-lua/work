--- CLI adapter for durable offline draft lifecycle and selection. Keeping the
--- workflow here leaves `_work.gitboard` as dispatch rather than manifest UI.
local gate = require("_work.gitgate")
local gitdraft = require("_work.gitdraft")

local function cmd_draft(root: string, args: {string}, print_id: boolean): integer
  local action = args[1] or ""
  if action == "begin" then
    if (os.getenv("GITBOARD_DRAFT") or "") ~= "" then
      return gate.verdict_line("draft", false,
        "REFUSED: unset GITBOARD_DRAFT before beginning another draft")
    end
    local opened, err = gitdraft.begin(root)
    if opened == nil then return gate.verdict_line("draft", false, err) end
    if print_id then print(opened.id); return 0 end
    print(("draft %s opened; local only"):format(opened.id))
    return gate.verdict_line("draft", true,
      "set GITBOARD_DRAFT=" .. opened.id .. " to compose offline mutations")
  end
  local selected = args[2] or os.getenv("GITBOARD_DRAFT") or ""
  if selected == "" then
    return gate.verdict_line("draft", false,
      "REFUSED: name a draft or set GITBOARD_DRAFT")
  end
  local opened, err = gitdraft.open(root, selected)
  if opened == nil then return gate.verdict_line("draft", false, err) end
  if action == "show" then
    print(("draft %s OPEN refs=%d"):format(opened.id, #opened.updates))
    for _, u in ipairs(gitdraft.plan(opened)) do
      print(("%s %s -> %s"):format(u.ref, u.expected, u.next))
    end
    return gate.verdict_line("draft", true,
      "local only; publish with `gitboard publish " .. opened.id .. "`")
  end
  if action == "abandon" then
    local removed, remove_err = gitdraft.abort(root, opened)
    if not removed then return gate.verdict_line("draft", false, remove_err) end
    return gate.verdict_line("draft", true,
      "local draft removed; canonical board and product commits untouched")
  end
  return gate.verdict_line("draft", false,
    "REFUSED: draft action must be begin, show, or abandon")
end

--- Activate an explicit/environment-selected draft for an ordinary command.
--- Claims are coordination gates and therefore intentionally excluded.
local function activate(root: string, command: string,
    explicit?: string): string | nil, string
  gitdraft.deactivate(root)
  local selected = explicit or os.getenv("GITBOARD_DRAFT") or ""
  if selected == "" or command == "publish" or command == "refresh" then
    return selected, ""
  end
  if command == "claim" or command == "renew" or command == "drop" then
    return nil, "claims are coordination gates outside drafts; unset GITBOARD_DRAFT"
  end
  local opened, err = gitdraft.open(root, selected)
  if opened == nil then return nil, err end
  local ok, activate_err = gitdraft.activate(root, opened)
  if not ok then return nil, activate_err end
  return selected, ""
end

local record gitdraft_cli
  cmd_draft: function(root: string, args: {string}, print_id: boolean): integer
  activate: function(root: string, command: string,
  explicit?: string): string | nil, string
end

local M: gitdraft_cli = {cmd_draft = cmd_draft, activate = activate}
return M
