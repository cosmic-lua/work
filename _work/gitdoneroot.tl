--- `done`'s board- and outcome-specific gates: `done` refuses the
--- board OUTRIGHT — it has no resolution of its own to record. An
--- OUTCOME's win condition is never verified by assertion, so
--- `--reason completed` needs `--by CHILD` — a completed child of that
--- outcome carrying the evidence — and the outcome must have no open
--- child left. `--reason not-planned` retires an outcome on the reason
--- alone and refuses `--by`, since it would record evidence a retired
--- outcome never had. Off an outcome, `--by` names nothing and is
--- refused. Split out of `_work.gitverbs` to keep that module under
--- its line cap.
local index = require("_work.index")
local item = require("_work.item")
local read = require("_work.read")

local type Index = index.Index

--- The refusal `done`'s board- and outcome-specific rules earn on
--- `it`, or nil when `done` may proceed. `by`, when given, is already
--- a FULL id — the dispatcher resolves prefixes before this ever runs.
--- @param c Index An index with `_work.readddl.ensure_views` applied
--- @param all {item.Item} Every item
--- @param it item.Item The item being ended
--- @param reason string "completed" | "not-planned"
--- @param by string The `--by` id, "" when none was given
--- @return string | nil The refusal
--- @return string Error message
local function done_refusal(c: Index, all: {item.Item}, it: item.Item,
    reason: string, by: string): string | nil, string
  local role, rerr = read.role(c, it.id)
  if role == nil then
    return nil, rerr
  end
  if role == "board" then
    return "the board is never done — it has no resolution of its own", ""
  end
  if role ~= "outcome" then
    if by ~= "" then
      return "--by names an outcome's evidence — meaningless off an outcome", ""
    end
    return nil, ""
  end
  if reason == "not-planned" then
    if by ~= "" then
      return "not-planned names no evidence — --by would record a "
      .. "completed child a retired outcome never had", ""
    end
    return nil, ""
  end
  for _, i in ipairs(all) do
    if i.parent == it.id and item.is_open(i) then
      return ("%s has an open child (%s) left — a verified outcome "
        .. "has none"):format(it.id:sub(1, 8), i.id:sub(1, 8)), ""
    end
  end
  if by == "" then
    return "a verified outcome names its evidence — pass --by CHILD, the "
    .. "completed child that carries it", ""
  end
  local child: item.Item = nil
  for _, i in ipairs(all) do
    if i.id == by then
      child = i
      break
    end
  end
  if child == nil then
    return ("no item %s"):format(by), ""
  end
  if child.parent ~= it.id then
    return ("%s is not %s's child — --by names the evidence, a child "
      .. "of the outcome it verifies"):format(by:sub(1, 8), it.id:sub(1, 8)), ""
  end
  if child.resolution ~= "completed" then
    return ("%s is not completed — --by names the child whose own "
      .. "resolution verified the outcome"):format(by:sub(1, 8)), ""
  end
  return nil, ""
end

local record gitdoneroot
  done_refusal: function(c: Index, all: {item.Item}, it: item.Item,
  reason: string, by: string): string, string
end

local M: gitdoneroot = {
  done_refusal = done_refusal,
}

return M
