local briefctx = require("_work.briefctx")

local function render(d: briefctx.ReviewingResearch): string
  local parts: {string} = {}
  parts[#parts + 1] = "This is a research handover: its deliverable is board state, not a product\ndiff. The commit under review lives in the BOARD repository (the clone at\n`"
  -- reviewing_research:3
  local v1: string = d.board_dir
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`), on the item's own ref — not in any product checkout — and\nits message body is the findings, carried verbatim below. Judge those\nfindings against the spec they answer; never substitute the item's current\ntip, a later entry, or any product commit for `"
  -- reviewing_research:6
  local v2: string = d.head_sha
  parts[#parts + 1] = v2
  parts[#parts + 1] = "`.\n\n## The findings this handover recorded (verbatim, the body of `"
  -- reviewing_research:8
  local v3: string = d.head_sha
  parts[#parts + 1] = v3
  parts[#parts + 1] = "`)\n\n---\n"
  -- reviewing_research:11
  local v4: string = d.findings
  parts[#parts + 1] = v4
  parts[#parts + 1] = "\n---\n\n## The spec these findings are supposed to answer (verbatim)\n"
  return table.concat(parts)
end

return {render = render}
