--- Caller-owned transport wrapper for the one-hop board migration.
--- Preparation is local and render-only by default; the explicit execution
--- path runs only the same ordinary Git argv printed to the caller.
local cache = require("_work.cache")
local gate = require("_work.gitgate")
local gitmigrate = require("_work.gitmigrate")
local prepared = require("_work.prepared")
local transport = require("_work.gittransport")

local function cmd_migrate(dir: string, remote: string,
    execute: boolean): integer
  local outcome, merr = gitmigrate.migrate(dir)
  if outcome == nil then return gate.verdict_line("migrate", false, merr) end
  if outcome.current then
    return gate.verdict_line("migrate", true, "board format is already current")
  end
  if outcome.applied then
    return gate.verdict_line("migrate", true,
      "local-only board migrated; item histories unchanged; cache rebuilt")
  end
  local tx = outcome.transaction
  if tx == nil then
    return gate.verdict_line("migrate", false,
      "migration prepared no publication transaction")
  end
  local push = prepared.push_argv(tx, remote)
  local fetch = prepared.fetch_argv(remote)
  if not execute then
    print(transport.render_argv(push))
    print(transport.render_argv(fetch))
    gate.verdict_line("migrate", true,
      "PREPARED: no board format change was published; run the printed push "
      .. "and fetch, then `gitboard refresh`")
    return 2
  end
  local pushed, perr = prepared.execute(dir, push)
  if not pushed then return gate.verdict_line("migrate", false, perr) end
  local fetched, ferr = prepared.execute(dir, fetch)
  if not fetched then
    gate.verdict_line("migrate", true,
      "CONFIRMATION PENDING: push completed but fetch failed: " .. ferr)
    return 2
  end
  local refreshed, rerr = prepared.refresh(dir, remote)
  if refreshed == nil then return gate.verdict_line("migrate", false, rerr) end
  for _, result in ipairs(refreshed) do
    if result.transaction.staging_ref == tx.staging_ref
    and result.state ~= "confirmed" then
      return gate.verdict_line("migrate", false, result.detail)
    end
  end
  local rebuilt, berr = cache.rebuild(dir)
  if rebuilt == nil then
    return gate.verdict_line("migrate", false,
      "format confirmed, but cache rebuild failed: " .. berr)
  end
  local closed, cerr = cache.close(rebuilt)
  if not closed then
    return gate.verdict_line("migrate", false,
      "format confirmed, but rebuilt cache could not close: " .. cerr)
  end
  return gate.verdict_line("migrate", true,
    "board format published and confirmed; item histories unchanged")
end

local record gitmigrate_cli
  cmd_migrate: function(dir: string, remote: string, execute: boolean): integer
end

local M: gitmigrate_cli = {cmd_migrate = cmd_migrate}
return M
