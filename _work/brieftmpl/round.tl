local briefctx = require("_work.briefctx")

local function render(d: briefctx.Round): string
  local parts: {string} = {}
  parts[#parts + 1] = "## Round "
  -- round:1
  local v1: string = d.round_number
  parts[#parts + 1] = v1
  parts[#parts + 1] = " context — this is a rework, not a fresh review\n\nRound "
  -- round:3
  local v2: string = d.round_number
  parts[#parts + 1] = v2
  parts[#parts + 1] = " requested changes on head `"
  -- round:3
  local v3: string = d.judged_head
  parts[#parts + 1] = v3
  parts[#parts + 1] = "`; the\nPR's head has since moved to `"
  -- round:4
  local v4: string = d.current_head
  parts[#parts + 1] = v4
  parts[#parts + 1] = "`. That round's review,\nverbatim:\n\n> "
  -- round:7
  local v5: string = d.round_finding
  parts[#parts + 1] = v5
  parts[#parts + 1] = "\n\nConfirm each finding above is closed — repeat its own reproduction —\nthen judge the whole diff; what round 1 accepted is settled.\n"
  return table.concat(parts)
end

return {render = render}
