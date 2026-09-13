local briefctx = require("_work.briefctx")

local function render(d: briefctx.Opening): string
  local parts: {string} = {}
  parts[#parts + 1] = "You are a fresh-context code reviewer for `"
  -- opening_diff:1
  local v1: string = d.repo
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`. You have never\nseen this change before — that is deliberate: the review must come\nfrom a distance from the builder. Everything you need is below.\n"
  return table.concat(parts)
end

return {render = render}
