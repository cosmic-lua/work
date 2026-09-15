--- Caller-owned native publication and confirmation commands.
local statepublish = require("_work.snapshot_publish")
local statepublish_cli = require("_work.statepublish_cli")
local gate = require("_work.gitgate")
local refs = require("_work.refs")
local store = require("_work.store")
local function render_argv(argv: {string}): string
  local words: {string} = {}
  for _, word in ipairs(argv) do
    if word:match("^[A-Za-z0-9_./:@+=,-]+$") then
      words[#words + 1] = word
    else
      words[#words + 1] = "'" .. word:gsub("'", "'\"'\"'") .. "'"
    end
  end
  return table.concat(words, " ")
end

local function cmd_publish(s: store.Store, selectors: {string}, remote: string, execute: boolean): integer
  return statepublish_cli.cmd_publish(s, selectors, remote, execute)
end
local function cmd_refresh(s: store.Store, remote: string, execute: boolean): integer
  if remote ~= refs.board_remote(s.root) then
    return gate.verdict_line("refresh", false, "native refresh destination differs")
  end
  local ok, detail = statepublish.sync(s, execute)
  return gate.verdict_line("refresh", ok, detail)
end
return {render_argv = render_argv, cmd_publish = cmd_publish, cmd_refresh = cmd_refresh}
