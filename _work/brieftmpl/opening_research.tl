local briefctx = require("_work.briefctx")

local function render(d: briefctx.Opening): string
  local parts: {string} = {}
  parts[#parts + 1] = "You are a fresh-context findings reviewer for `"
  -- opening_research:1
  local v1: string = d.repo
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`. You have never\nseen these findings before — that is deliberate: the review must come\nfrom a distance from the researcher. Everything you need is below.\n"
  return table.concat(parts)
end

return {render = render}
