local briefctx = require("_work.briefctx")

local function render(d: briefctx.Review): string
  local parts: {string} = {}
  -- review:1
  local v1: string = d.opening
  parts[#parts + 1] = v1
  parts[#parts + 1] = "\n## What you're reviewing\n\nBoard item id: `"
  -- review:4
  local v2: string = d.item_id
  parts[#parts + 1] = v2
  parts[#parts + 1] = "` (handle "
  -- review:4
  local v3: string = d.handle
  parts[#parts + 1] = v3
  parts[#parts + 1] = ")\nTitle: "
  -- review:5
  local v4: string = d.title
  parts[#parts + 1] = v4
  parts[#parts + 1] = "\n"
  -- review:6
  local v5: string = d.change_source
  parts[#parts + 1] = v5
  parts[#parts + 1] = "\n\n"
  -- review:8
  local v6: string = d.reviewing
  parts[#parts + 1] = v6
  parts[#parts + 1] = "\n---\n"
  -- review:10
  local v7: string = d.spec
  parts[#parts + 1] = v7
  parts[#parts + 1] = "\n---\n\n"
  -- review:13
  local v8: string = d.round_context
  parts[#parts + 1] = v8
  parts[#parts + 1] = "\n"
  -- review:14
  local v9: string = d.posture
  parts[#parts + 1] = v9
  parts[#parts + 1] = "\nA request-changes verdict names five labeled facts, not a fix: the\nexact reproducer; the smallest permitted correction boundary; the\ntempting unsafe repair, when one is visible; the adjacent invariant\nthat repair could violate; and the focused regression plus every\nnamed boundary guard the corrected head must rerun. Do not design\nthe correction: when no safe envelope is established, name the\nuncertainty and let the rework builder bounce rather than widening\nscope to find one.\n"
  return table.concat(parts)
end

return {render = render}
