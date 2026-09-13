local briefctx = require("_work.briefctx")

local function render(d: briefctx.ReviewingDiff): string
  local parts: {string} = {}
  parts[#parts + 1] = "The caller has made this exact commit available in your local checkout.\nReview `"
  -- reviewing_diff:2
  local v1: string = d.claim_base
  parts[#parts + 1] = v1
  parts[#parts + 1] = ".."
  -- reviewing_diff:2
  local v2: string = d.head_sha
  parts[#parts + 1] = v2
  parts[#parts + 1] = "`; never substitute a branch tip or provider\nstate for either commit. The spec below is authoritative. External checks,\nwhen used, must be inspected by the caller on this exact SHA.\n\n## The spec this PR is supposed to satisfy (verbatim)\n"
  return table.concat(parts)
end

return {render = render}
