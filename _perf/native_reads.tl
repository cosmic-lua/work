#!/usr/bin/env cosmic
--- Measure invocation-local projection reuse on an already activated board.
--- Run on an isolated audit clone; this reads objects and the disposable cache.
local boardhistory = require("_work.boardhistory")
local boardread = require("_work.boardread")
local check = require("cosmic.check")
local literal = require("_work.singlehead_literal")
local publish = require("_work.publish")
local store = require("_work.store")

local root = assert(arg[1], "expected an isolated native board directory")
local old_view, old_history = boardread.list, boardhistory.read
local views, histories = 0, 0
boardread.list = function(dir: string, head: string, now?: integer): boardread.View | nil, string
  views = views + 1
  return old_view(dir, head, now)
end
boardhistory.read = function(dir: string, head: string, before?: string): boardhistory.History | nil, string
  histories = histories + 1
  return old_history(dir, head, before)
end
local s = check.must(store.open(root))
local items = check.must(store.list(s))
local events, loads, resolutions, specs = 0, 0, 0, 0
for _, it in ipairs(items) do
  assert(check.must(store.resolve(s, it.id)) == it.id)
  resolutions = resolutions + 1
  for _ = 1, 3 do
    assert(check.must(store.load(s, it.id)).id == it.id)
    loads = loads + 1
  end
  store.read_spec(s, it.id)
  specs = specs + 1
  events = events + #check.must(publish.history(s, it.id))
end
assert(views == 1 and histories == 1, "one view and one history per invocation head: "
  .. tostring(views) .. " views, " .. tostring(histories) .. " histories")
assert(store.close(s))
print(check.must(literal.encode({format = "gitboard-native-read-memo-v1",
        head = s.state_head, items = #items, loads = loads, resolutions = resolutions,
        specs = specs, item_events = events, full_view_reads = views,
        full_history_reads = histories})))
