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
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it.\n\n## Recording your verdict\n\nYou do not run `verdict` — no spawned agent runs a board verb. The caller\nrecords your verdict with `verdict ID KIND --head SHA --session S`, which\nverifies and records one local commit id — here the board commit itself,\njudged in the board clone, so the record names no product checkout. It\nperforms no fetch, credential lookup, check read, merge, or provider\nwrite. The caller owns those operations, and so does watching them: never\npoll or subscribe to a provider event yourself. This review is claimed\nunder session `"
  -- posture_research:54
  local v5: string = d.review_session
  parts[#parts + 1] = v5
  parts[#parts + 1] = "` — you MUST use that exact string. You\nrun no board command, so never bootstrap a `bin/gitboard` loader yourself —\nthe reproduction worktree above is the one tree you bootstrap.\n\nYour final report carries exactly one verdict line, in this fixed envelope,\nand your findings follow it:\n\n```\nverdict: accept|request-changes|reject head="
  -- posture_research:62
  local v6: string = d.head_sha
  parts[#parts + 1] = v6
  parts[#parts + 1] = " session="
  -- posture_research:62
  local v7: string = d.review_session
  parts[#parts + 1] = v7
  parts[#parts + 1] = "\n```\n\nWrite exactly the one kind matching your judgment. The board stores the SHA,\nnot review prose. Put concrete gaps in your final report for the caller. An\naccept does not merge or complete the item, and a research item lands\nnothing — its deliverable is the board commit itself — so the caller runs\n`done "
  -- posture_research:69
  local v8: string = d.item_id
  parts[#parts + 1] = v8
  parts[#parts + 1] = " --landed "
  -- posture_research:69
  local v9: string = d.head_sha
  parts[#parts + 1] = v9
  parts[#parts + 1] = "`.\n\n## Final report\n\nThe verdict you recorded (or why you could not), each measured claim you\nre-ran and whether it reproduced, and any concrete gaps quoted from the\nfindings' own text. Keep it factual and concise.\n"
  return table.concat(parts)
end

return {render = render}
