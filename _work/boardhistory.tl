--- First-parent format-6 history, attributed by changed item and claim paths.
local child = require("cosmic.child")
local events = require("_work.events")
local literal = require("_work.singlehead_literal")
local NOT_FAST_FORWARD < const > = "native history range is not a first-parent continuation"

local record boardhistory
  record HistoryEvent
    item: string sha: string at: integer author: string subject: string
    verb: string session: string pr: integer
  end
  record History
    events: {HistoryEvent}
    events_by_id: {string: {HistoryEvent}}
    tip_by_id: {string: string}
    touched_by_id: {string: integer}
  end
  read: function(root: string, head: string, before?: string): History | nil, string
  logical_author: function(string, string): string
  NOT_FAST_FORWARD: string
end
local type HistoryEvent = boardhistory.HistoryEvent
local type History = boardhistory.History

--- The author a commit means, which is not always the one Git recorded: a
--- connector that cannot set the author writes its own identity and carries the
--- session's in the `Gitboard-Author` trailer, so that trailer wins when it
--- parses and the physical author stands in when it does not.
--- @param value string The trailer's value, "" when the commit has none
--- @param fallback string The physical `Name <email>` Git recorded
--- @return string `Name <email>` to attribute the commit to
local function logical_author(value: string, fallback: string): string
  if value == "" then return fallback end
  local decoded = literal.decode_object(value)
  if decoded == nil then return fallback end
  local name, email = decoded.name, decoded.email
  if not (name is string) or not (email is string) then return fallback end
  return name .. " <" .. email .. ">"
end

--- The branch's first-parent history as board events, attributed BY PATH: a
--- commit naming `items/<id>/` or `claims/<id>` is an event of that item, so a
--- claim batch of N members yields N rows, and the newest commit naming an
--- item is its tip and `touched_at`. One `git log`, whatever the board's size.
--- Trailer parsing is pinned with explicit `-c` overrides so ambient
--- configuration cannot change who a commit is attributed to.
--- @param root string The repository holding `head`
--- @param head string The exact commit to walk back from
--- @param before string | nil Stop at this previously indexed first-parent head
--- @return History | nil Events oldest-first, with each item's tip and date
--- @return string Error message
local function read(root: string, head: string, before?: string): History | nil, string
  local argv = {"git", "-c", "core.commentChar=#", "-c", "trailer.separators=:",
    "-c", "trailer.Gitboard-Author.key=Gitboard-Author", "log", "--first-parent",
    "--format=%x1e%H%x00%ct%x00%an <%ae>%x00%s%x00%P%x00%(trailers:key=Gitboard-Author,valueonly,unfold)",
    "--name-only", head}
  if before ~= nil then argv[#argv + 1] = "^" .. before end
  local r, err = child.run(argv, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, "git log failed: " .. r.stderr end
  local newest: {HistoryEvent} = {}
  local oldest_parent = ""
  local tips: {string: string} = {}; local touched: {string: integer} = {}
  for chunk in r.stdout:gmatch("\30([^\30]+)") do
    local header, paths = chunk:match("^([^\n]*)\n(.*)$")
    if header == nil then header, paths = chunk, "" end
    local sha, at_s, physical, subject, parents, logical =
    header:match("^([^\0]+)\0([^\0]+)\0([^\0]+)\0([^\0]*)\0([^\0]*)\0([^\n]*)")
    if sha ~= nil then
      oldest_parent = parents:match("^([^ ]+)") or ""
      local author = logical_author(logical or "", physical)
      local ids: {string: boolean} = {}
      for path in paths:gmatch("([^\n]+)") do
        local id = path:match("^items/([^/]+)/") or path:match("^claims/([^/]+)$")
        if id ~= nil then ids[id] = true end
      end
      local parsed = events.parse_subject(subject)
      for id in pairs(ids) do
        local at = math.tointeger(tonumber(at_s)) or 0
        newest[#newest + 1] = {item = id, sha = sha, at = at, author = author,
          subject = subject, verb = parsed.verb, session = parsed.session, pr = parsed.pr}
        if tips[id] == nil then tips[id], touched[id] = sha, at end
      end
    end
  end
  if before ~= nil and head ~= before and oldest_parent ~= before then
    return nil, NOT_FAST_FORWARD
  end
  local out: History = {events = {}, events_by_id = {}, tip_by_id = tips, touched_by_id = touched}
  for i = #newest, 1, -1 do
    local ev = newest[i]; out.events[#out.events + 1] = ev
    out.events_by_id[ev.item] = out.events_by_id[ev.item] or {}
    out.events_by_id[ev.item][#out.events_by_id[ev.item] + 1] = ev
  end
  return out
end

local M: boardhistory = {read = read, logical_author = logical_author,
  NOT_FAST_FORWARD = NOT_FAST_FORWARD}
return M
