local briefctx = require("_work.briefctx")

local function render(d: briefctx.Rework): string
  local parts: {string} = {}
  parts[#parts + 1] = "## This is a rework, not a fresh pull\n\nThe item carries `request changes` on commit `"
  -- rework:3
  local v1: string = d.judged_head
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`. Reuse its\nexisting worktree and branch — do NOT branch fresh and do NOT discard the\ndiff already there. Before touching anything, confirm the worktree at\n`"
  -- rework:6
  local v2: string = d.worktree
  parts[#parts + 1] = v2
  parts[#parts + 1] = "` still exists, `git status` is clean, and its history contains\nthat commit; if it does not, stop and report the mismatch rather than\nrebuilding it from scratch.\n\nThe board deliberately stores no review prose: its evidence is only the\njudged commit id. Apply the findings supplied by the caller, commit the\nrepair on `"
  -- rework:12
  local v3: string = d.branch
  parts[#parts + 1] = v3
  parts[#parts + 1] = "`, and report the new commit id for a new handover.\n\nEvery correction produces a NEW candidate head, and a new head\ninvalidates every prior verification: `"
  -- rework:15
  local v4: string = d.judged_head
  parts[#parts + 1] = v4
  parts[#parts + 1] = "`'s cold-build,\ngate, or guard result is evidence about `"
  -- rework:16
  local v5: string = d.judged_head
  parts[#parts + 1] = v5
  parts[#parts + 1] = "`, not about\nwhatever you commit next. Never carry one forward with a claim like\n\"the prior cold-build remains green\" once the head has moved, however\nsmall or unrelated the correction looks.\n\nBefore handover:\n\n1. add or identify the focused regression that pins the reported\n   finding — the new head must fail without your fix and pass with it;\n2. diff the rejected head against the new head (`git diff "
  -- rework:25
  local v6: string = d.judged_head
  parts[#parts + 1] = v6
  parts[#parts + 1] = "\n   <new head>`) and name, in your final report, the boundaries the\n   correction crosses — a signature another file calls, a pre-install\n   boundary module, a tracking file's shape — not just the finding\n   restated;\n3. rerun every acceptance/guard command the item spec names explicitly,\n   even when the correction looks unrelated to what that command\n   checks.\n\nThis is not a license to rerun `--make ci` (or the target repo's own\ngate) on every rework: keep reaching for the one focused guard a\nfinding names or implies, same as any other builder turn.\n"
  return table.concat(parts)
end

return {render = render}
