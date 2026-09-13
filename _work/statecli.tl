--- Native-specific CLI adapters; provider actions remain caller-owned.
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local literal = require("_work.singlehead_literal")
local migrate = require("_work.migrate6")
local refs = require("_work.refs")
local store = require("_work.store")
local tail = require("_work.tail")

local function resolve(s: store.Store, input: string): string | nil, string
  local items, err = store.list(s)
  if items == nil then return nil, err end
  local wanted = tail.normalize(input):lower()
  local ids: {string} = {}
  for _, it in ipairs(items) do
    if it.id:sub(-8):lower() == wanted then ids[#ids + 1] = it.id end
  end
  if #ids == 1 then return ids[1], "" end
  if #ids == 0 then return nil, "no item matches tail " .. input end
  return nil, input .. " is ambiguous: " .. tail.join_handles(ids)
end

local function migration(root: string, args: {string}, values: {string: string},
    switches: {string: boolean}): integer
  local path = values.checkpoint or fs.join(root, "o/migrate6/checkpoint.literal")
  local action = args[1] or "plan"
  local checkpoint: migrate.Checkpoint | nil = nil
  local err = ""
  if action == "plan" then
    local prefix = values.prefix or (refs.board_mode(root) == "local" and "refs/heads/"
      or "refs/remotes/" .. refs.board_remote(root) .. "/")
    checkpoint, err = migrate.run(root, {checkpoint = path, prefix = prefix,
        catch_up = switches["catch-up"] or false, state_ref = prefix .. "state"})
  elseif action == "show" or action == "verify-source" then
    checkpoint, err = migrate.read(path)
  else
    return gate.verdict_line("migrate6", false, "action must be plan, show, or verify-source")
  end
  if checkpoint == nil then return gate.verdict_line("migrate6", false, err) end
  if action == "verify-source" then
    local valid, verr = migrate.validate_sources(root, checkpoint)
    return gate.verdict_line("migrate6", valid, valid and "source ref set matches checkpoint" or verr)
  end
  local raw, rerr = literal.encode(checkpoint)
  if raw == nil then return gate.verdict_line("migrate6", false, rerr) end
  print(raw)
  return gate.verdict_line("migrate6", true, action == "plan" and err or "checkpoint inspected")
end

local record statecli
  resolve: function(s: store.Store, input: string): string | nil, string
  migration: function(root: string, args: {string}, values: {string: string}, switches: {string: boolean}): integer
end
local M: statecli = {resolve = resolve, migration = migration}
return M
