--- Native publication and invocation-local path-attributed history.
local statepublish = require("_work.snapshot_publish")
local store = require("_work.store")
local refs = require("_work.refs")
local record Event
  sha: string
  at: string
  subject: string
end
local function has_origin(s: store.Store): boolean
  if not s.remote_present_read then
    local r = store.git(s, {"remote"})
    local wanted = refs.board_remote(s.root)
    s.remote_present = r ~= nil and r.ok
    and ("\n" .. r.stdout .. "\n"):find("\n" .. wanted .. "\n", 1, true) ~= nil
    s.remote_present_read = true
  end
  return s.remote_present
end

local function iso8601_z(epoch: integer): string
  return os.date("!%Y-%m-%dT%H:%M:%SZ", epoch) as string -- cast: os.date with a format string always returns string
end
local function history(s: store.Store, id?: string): {Event} | nil, string
  local native_history, err = store.history(s)
  if native_history == nil then return nil, err end
  local rows = id ~= nil and (native_history.events_by_id[id] or {}) or native_history.events
  local out: {Event} = {}
  local seen: {string: boolean} = {}
  for i = #rows, 1, -1 do
    local row = rows[i]
    if not seen[row.sha] then
      seen[row.sha] = true
      out[#out + 1] = {sha = row.sha:sub(1, 7), at = iso8601_z(row.at), subject = row.subject}
    end
  end
  return out, ""
end
local function touched_at(s: store.Store, id: string): integer | nil, string
  local timeline, err = store.history(s)
  if timeline == nil then return nil, err end
  local at = timeline.touched_by_id[id]
  if at == nil then return nil, "no item " .. id end
  return at, ""
end
local record publish_module
  type Event = Event
  has_origin: function(s: store.Store): boolean
  sync: function(s: store.Store, execute?: boolean): boolean, string
  publish: function(s: store.Store, execute?: boolean): boolean, string
  history: function(s: store.Store, id?: string): {Event} | nil, string
  touched_at: function(s: store.Store, id: string): integer | nil, string
end

local M: publish_module = {
  has_origin = has_origin,
  sync = statepublish.sync,
  publish = statepublish.publish,
  history = history,
  touched_at = touched_at,
}

return M
