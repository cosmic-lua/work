--- Native-specific CLI adapters; provider actions remain caller-owned.
local migrate = require("_work.migrate6_cli")
local store = require("_work.store")
local tail = require("_work.tail")

--- The item a handle names on a native board, matched on the id's last eight
--- characters, preferring an exact match before case folding — no
--- ref enumeration.
--- @param s store.Store The open store
--- @param input string A handle, in any of the forms `tail.normalize` accepts
--- @return string | nil The full item id
--- @return string Error message: nothing matched, or the matches
local function resolve(s: store.Store, input: string): string | nil, string
  local view, err = store.view(s)
  if view == nil then return nil, err end
  local ids: {string} = {}
  for _, it in ipairs(view.items) do ids[#ids + 1] = it.id end
  return tail.resolve_ids(ids, input)
end

local record statecli
  resolve: function(s: store.Store, input: string): string | nil, string
  migration: function(root: string, args: {string}, values: {string: string}, switches: {string: boolean}): integer
end
local M: statecli = {resolve = resolve, migration = migrate.run}
return M
