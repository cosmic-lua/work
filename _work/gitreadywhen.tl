--- The live half of the Ready-when mechanism (`_work.overlap.ready_when`
--- is the pure evaluator): whether the head `next` decided to
--- recommend is one this session may actually start on, and what to
--- recommend instead when it is not.
---
--- Split out of `_work.gitview`, which sits at the repo's line cap —
--- the only room this mechanism's `next`-side hook had left.
local action = require("_work.action")
local overlap = require("_work.overlap")

local type Action = action.Action

--- The decided HEAD action, adjusted for its own Ready-when: unchanged
--- when it is not a pull, when its item's spec names no `Ready when:`
--- sentence, or when the command it names already matches. A
--- mismatching pull is never offered — its first alternate is
--- promoted in its place, carrying whatever alternates were left
--- behind it — the same way a queued-accept head is skipped and the
--- walk moves to the next row, except here there is no next row to
--- walk: the promoted alternate is never itself re-evaluated, since
--- only the head is worth a process spawn.
--- @param decided Action The action `_work.action.next_action` chose
--- @param specs action.Specs Spec sidecar body by item id
--- @return string The `not ready: ...` line to print ahead of it, "" when none
--- @return Action The action to actually recommend
local function skip_not_ready(decided: Action, specs: action.Specs): string, Action
  if decided.kind ~= "pull" or decided.item == nil then
    return "", decided
  end
  local not_ready = overlap.ready_when(specs[decided.item.id] or "")
  if not_ready == nil then
    return "", decided
  end
  local alts = decided.alternates or {}
  local promoted = alts[1]
  if promoted == nil then
    return not_ready, {kind = "none",
      reason = "the highest-ranked candidate is not ready, and nothing "
      .. "else passes the spec bar"}
  end
  local rest: {Action} = {}
  for k = 2, #alts do
    rest[#rest + 1] = alts[k]
  end
  promoted.alternates = rest
  return not_ready, promoted
end

local record gitreadywhen
  skip_not_ready: function(decided: Action, specs: action.Specs): string, Action
end

local M: gitreadywhen = {
  skip_not_ready = skip_not_ready,
}

return M
