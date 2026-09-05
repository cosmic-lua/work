--- The `sync` verb: rebase against the remote, then ask lane health
--- (`_work.lanes`) and PR CI observation (`_work.ciobs`) each to do
--- their own observe pipeline and hand back the lines to print. A
--- `nil` observe (offline, no token) prints and is never treated as
--- red. Split from `_work.gitverbs`, which sits against the file cap.
local ciobs = require("_work.ciobs")
local gate = require("_work.gitgate")
local lanes = require("_work.lanes")
local publish = require("_work.publish")
local store = require("_work.store")

--- Rebase this checkout against the remote, then print lane health and
--- PR CI observations.
--- @param s store.Store The store
--- @return integer Exit code
local function cmd_sync(s: store.Store): integer
  local ok, err = publish.sync(s)
  if not ok then
    return gate.verdict_line("sync", false, err)
  end
  for _, line in ipairs(lanes.at_sync(s)) do
    print(line)
  end
  for _, line in ipairs(ciobs.at_sync(s)) do
    print(line)
  end
  return gate.verdict_line("sync", true, "state is current")
end

local record gitsync
  cmd_sync: function(s: store.Store): integer
end

local M: gitsync = {
  cmd_sync = cmd_sync,
}

return M
