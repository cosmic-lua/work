local briefctx = require("_work.briefctx")

local function render(d: briefctx.PostureResearch): string
  local parts: {string} = {}
  parts[#parts + 1] = "## How to review — the posture is ADVERSARIAL\n\nYour job is to try to make these findings fail, not to confirm they\nread well. There is no diff here: the deliverable is board state, and a\nfindings review checks the findings the way a diff review checks a diff.\n\n1. Confirm you are reading exactly `"
  -- posture_research:7
  local v1: string = d.head_sha
  parts[#parts + 1] = v1
  parts[#parts + 1] = "` — the board commit on\n   the item's own ref whose message body is the findings above. Never\n   substitute the item's current tip or a later entry for it; that\n   commit is what your verdict names.\n2. Every measured claim names its command, and the command reproduces.\n   For each number, count, or behavior the findings assert, the findings\n   name the command that produced it and the commit it was measured at;\n   re-run that command against the product tree at that commit — a\n   checkout of your own, never the orchestrator's — and compare. A claim\n   with no command, a command that does not reproduce, or a measurement\n   with no commit named is a finding — quote it.\n3. The recommendation follows from the measurements and not past them:\n   each step it proposes rests on a measurement above it, and no\n   measurement is contradicted or left unaccounted for. A recommendation\n   that reaches beyond what was measured is a finding — quote the reach.\n4. Nothing the spec asked to be measured is missing: read the spec's\n   `## Change` as the list of what was to be measured and confirm each\n   entry has its measurement in the findings. An unanswered question is\n   a finding, even when the findings say why it was skipped.\n5. The findings are prospective evidence for the item's parent chain,\n   not a narrative: what they establish must be usable by the next item\n   as commands, commits, and numbers to build from, not a story of what\n   the researcher did. Judge them against the outcome the parent chain\n   exists for, not just the letter of `## Change`.\n\nThere is no guard to mutation-test and no product worktree to do it\nfrom: the deliverable is board state, judged where it lives. The\ncheckout that holds the board worktree (`"
  -- posture_research:34
  local v2: string = d.board_dir
  parts[#parts + 1] = v2
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it.\n\n## Recording your verdict\n\n`verdict` verifies and records one local commit id — here the board\ncommit itself, judged in the board clone, so the lines below name no\nproduct checkout. It performs no fetch, credential lookup, check read,\nmerge, or provider write. The caller owns those operations. This review\nis claimed under session `"
  -- posture_research:44
  local v3: string = d.review_session
  parts[#parts + 1] = v3
  parts[#parts + 1] = "` — you MUST use that exact\nstring.\n\nGitBoard invocation for this review: `"
  -- posture_research:47
  local v4: string = d.gitboard_cmd
  parts[#parts + 1] = v4
  parts[#parts + 1] = "` — the exact\nloader and absolute executable the caller runs board commands through.\nUse it verbatim as the prefix below; never guess a product-checkout\nsubstitute of your own, and never bootstrap one yourself.\n\n```\n"
  -- posture_research:53
  local v5: string = d.gitboard_cmd
  parts[#parts + 1] = v5
  parts[#parts + 1] = " verdict "
  -- posture_research:53
  local v6: string = d.item_id
  parts[#parts + 1] = v6
  parts[#parts + 1] = " accept \\\n  --head "
  -- posture_research:54
  local v7: string = d.head_sha
  parts[#parts + 1] = v7
  parts[#parts + 1] = " --session "
  -- posture_research:54
  local v8: string = d.review_session
  parts[#parts + 1] = v8
  parts[#parts + 1] = "\n"
  -- posture_research:55
  local v9: string = d.gitboard_cmd
  parts[#parts + 1] = v9
  parts[#parts + 1] = " verdict "
  -- posture_research:55
  local v10: string = d.item_id
  parts[#parts + 1] = v10
  parts[#parts + 1] = " request-changes \\\n  --head "
  -- posture_research:56
  local v11: string = d.head_sha
  parts[#parts + 1] = v11
  parts[#parts + 1] = " --session "
  -- posture_research:56
  local v12: string = d.review_session
  parts[#parts + 1] = v12
  parts[#parts + 1] = "\n"
  -- posture_research:57
  local v13: string = d.gitboard_cmd
  parts[#parts + 1] = v13
  parts[#parts + 1] = " verdict "
  -- posture_research:57
  local v14: string = d.item_id
  parts[#parts + 1] = v14
  parts[#parts + 1] = " reject \\\n  --head "
  -- posture_research:58
  local v15: string = d.head_sha
  parts[#parts + 1] = v15
  parts[#parts + 1] = " --session "
  -- posture_research:58
  local v16: string = d.review_session
  parts[#parts + 1] = v16
  parts[#parts + 1] = "\n```\n"
  return table.concat(parts)
end

return {render = render}
