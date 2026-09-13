--- Native-specific CLI adapters; provider actions remain caller-owned.
local migrate = require("_work.migrate6_cli")
local store = require("_work.store")
local tail = require("_work.tail")

--- The item a handle names on a native board, matched on the id's last eight
--- characters exactly as the ref-layout reader does — one whole-board read, no
--- ref enumeration.
--- @param s store.Store The open store
--- @param input string A handle, in any of the forms `tail.normalize` accepts
--- @return string | nil The full item id
--- @return string Error message: nothing matched, or the matches
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

local record statecli
  resolve: function(s: store.Store, input: string): string | nil, string
  migration: function(root: string, args: {string}, values: {string: string}, switches: {string: boolean}): integer
end
local M: statecli = {resolve = resolve, migration = migrate.run}
return M
