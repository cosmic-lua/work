local briefctx = require("_work.briefctx")

local function render(d: briefctx.PostureResearch): string
  local parts: {string} = {}
  parts[#parts + 1] = "## How to review — the posture is ADVERSARIAL\n\nYour job is to try to make these findings fail, not to confirm they\nread well. There is no diff here: the deliverable is board state, and a\nfindings review checks the findings the way a diff review checks a diff.\n\n1. Confirm you are reading exactly `"
  -- posture_research:7
  local v1: string = d.head_sha
  parts[#parts + 1] = v1
  parts[#parts + 1] = "` — the board commit on\n   the item's own ref whose message body is the findings above. Never\n   substitute the item's current tip or a later entry for it; that\n   commit is what your verdict names.\n2. Every measured claim names its command, and the command reproduces.\n   For each number, count, or behavior the findings assert, the findings\n   name the command that produced it and the commit it was measured at;\n   re-run that command at that commit and compare. Reproduction needs a\n   tree and this brief hands you none: make your own with\n   `git worktree add <dir> <commit>` from the product checkout at\n   `"
  -- posture_research:17
  local v2: string = d.product_root
  parts[#parts + 1] = v2
  parts[#parts + 1] = "` — the item's repository, `"
  -- posture_research:17
  local v3: string = d.repo
  parts[#parts + 1] = v3
  parts[#parts + 1] = "`, as the\n   caller's `gitboard.repository` map places it — and run there, never\n   in that checkout itself. Bootstrap that worktree the way the product\n   repository's own instructions (its AGENTS.md) bootstrap a new\n   checkout, before the first re-run. A claim with no command, a command\n   that does not reproduce, or a measurement with no commit named is a\n   finding — quote it.\n3. The recommendation follows from the measurements and not past them:\n   each step it proposes rests on a measurement above it, and no\n   measurement is contradicted or left unaccounted for. A recommendation\n   that reaches beyond what was measured is a finding — quote the reach.\n4. Nothing the spec asked to be measured is missing: read the spec's\n   `## Change` as the list of what was to be measured and confirm each\n   entry has its measurement in the findings. An unanswered question is\n   a finding, even when the findings say why it was skipped.\n5. The findings are prospective evidence for the item's parent chain,\n   not a narrative: what they establish must be usable by the next item\n   as commands, commits, and numbers to build from, not a story of what\n   the researcher did. Judge them against the outcome the parent chain\n   exists for, not just the letter of `## Change`.\n\nThere is no guard to mutation-test: the deliverable is board state,\njudged where it lives, and the only product tree you touch is the\nreproduction worktree above.\nThe checkout that holds the board worktree (`"
  -- posture_research:41
  local v4: string = d.board_dir
  parts[#parts + 1] = v4
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it.\n\n## Recording your verdict\n\n`verdict` verifies and records one local commit id — here the board\ncommit itself, judged in the board clone, so the lines below name no\nproduct checkout. It performs no fetch, credential lookup, check read,\nmerge, or provider write. The caller owns those operations. This review\nis claimed under session `"
  -- posture_research:51
  local v5: string = d.review_session
  parts[#parts + 1] = v5
  parts[#parts + 1] = "` — you MUST use that exact\nstring.\n\nGitBoard invocation for this review: `"
  -- posture_research:54
  local v6: string = d.gitboard_cmd
  parts[#parts + 1] = v6
  parts[#parts + 1] = "` — the exact\nloader and absolute executable the caller runs board commands through.\nUse it verbatim as the prefix below; never substitute a `bin/gitboard`\nfrom a product checkout, and never bootstrap that loader yourself — the\nreproduction worktree above is the one tree you bootstrap.\n\n```\n"
  -- posture_research:61
  local v7: string = d.gitboard_cmd
  parts[#parts + 1] = v7
  parts[#parts + 1] = " verdict "
  -- posture_research:61
  local v8: string = d.item_id
  parts[#parts + 1] = v8
  parts[#parts + 1] = " accept \\\n  --head "
  -- posture_research:62
  local v9: string = d.head_sha
  parts[#parts + 1] = v9
  parts[#parts + 1] = " --session "
  -- posture_research:62
  local v10: string = d.review_session
  parts[#parts + 1] = v10
  parts[#parts + 1] = "\n"
  -- posture_research:63
  local v11: string = d.gitboard_cmd
  parts[#parts + 1] = v11
  parts[#parts + 1] = " verdict "
  -- posture_research:63
  local v12: string = d.item_id
  parts[#parts + 1] = v12
  parts[#parts + 1] = " request-changes \\\n  --head "
  -- posture_research:64
  local v13: string = d.head_sha
  parts[#parts + 1] = v13
  parts[#parts + 1] = " --session "
  -- posture_research:64
  local v14: string = d.review_session
  parts[#parts + 1] = v14
  parts[#parts + 1] = "\n"
  -- posture_research:65
  local v15: string = d.gitboard_cmd
  parts[#parts + 1] = v15
  parts[#parts + 1] = " verdict "
  -- posture_research:65
  local v16: string = d.item_id
  parts[#parts + 1] = v16
  parts[#parts + 1] = " reject \\\n  --head "
  -- posture_research:66
  local v17: string = d.head_sha
  parts[#parts + 1] = v17
  parts[#parts + 1] = " --session "
  -- posture_research:66
  local v18: string = d.review_session
  parts[#parts + 1] = v18
  parts[#parts + 1] = "\n```\n\nRun exactly the one line matching your judgment. The board stores the SHA,\nnot review prose. Put concrete gaps in your final report for the caller. An\naccept does not merge or complete the item, and a research item lands\nnothing — its deliverable is the board commit itself — so the caller runs\n`"
  -- posture_research:73
  local v19: string = d.gitboard_cmd
  parts[#parts + 1] = v19
  parts[#parts + 1] = " done "
  -- posture_research:73
  local v20: string = d.item_id
  parts[#parts + 1] = v20
  parts[#parts + 1] = " --landed "
  -- posture_research:73
  local v21: string = d.head_sha
  parts[#parts + 1] = v21
  parts[#parts + 1] = "`.\n\n## Final report\n\nThe verdict you recorded (or why you could not), each measured claim you\nre-ran and whether it reproduced, and any concrete gaps quoted from the\nfindings' own text. Keep it factual and concise.\n"
  return table.concat(parts)
end

return {render = render}
