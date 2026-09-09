--- Session-label formatting and item-wide completed-verdict review rounds.
local events = require("_work.events")
local publish = require("_work.publish")
local session = require("_work.session")
local store = require("_work.store")
local tail = require("_work.tail")

--- Builder claims use `build`; every other kind keeps its own name.
local LABEL_KIND < const >: {string: string} = {
  builder = "build",
  research = "research",
  review = "review",
  refine = "refine",
  decompose = "decompose",
}

--- Unsuffixed compatibility formatter, independent of item history. The
--- caller's session prefix separates different orchestrators. cmd_brief's
--- review path adds the completed-verdict round using `review` below.
--- @param kind string The brief kind
--- @param handle string The item's bare tail
--- @return string The base label
local function mint_label(kind: string, handle: string): string
  local identity = session.resolve(nil)
  local orch8 = identity:sub(1, 8)
  if orch8 == "" then
    orch8 = "unnamed"
  end
  return ("%s-%s-%s"):format(LABEL_KIND[kind] or kind, handle, orch8)
end

--- Count every persisted verdict, including legacy PR/result subjects.
--- New handovers clear standing acceptance, not this lifetime history.
--- Reading a brief never allocates a round or reserves a session label.
--- @param s store.Store The store
--- @param id string The full item id
--- @return string | nil The numbered review label
--- @return string History read error
local function review(s: store.Store, id: string): string | nil, string
  local history, err = publish.history(s, id)
  if history == nil then
    return nil, err
  end
  local round = 1
  for _, event in ipairs(history) do
    if events.parse_subject(event.subject).verb == "verdict" then
      round = round + 1
    end
  end
  local label = mint_label("review", tail.bare(id))
  if round > 1 then
    label = label .. "-" .. tostring(round)
  end
  return label, ""
end

local record brief_label
  mint_label: function(kind: string, handle: string): string
  review: function(s: store.Store, id: string): string | nil, string
end

local M: brief_label = {mint_label = mint_label, review = review}
return M
