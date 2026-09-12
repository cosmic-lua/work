local briefctx = require("_work.briefctx")

local function render(d: briefctx.ReviewScript): string
  local parts: {string} = {}
  parts[#parts + 1] = "You are a fresh-context code reviewer for `"
  -- review_script:1
  local v1: string = d.repo
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`. You have never\nseen this change before — that is deliberate: the review must come\nfrom a distance from the builder. Everything you need is below.\n\n## What you're reviewing\n\nBoard item id: `"
  -- review_script:7
  local v2: string = d.item_id
  parts[#parts + 1] = v2
  parts[#parts + 1] = "` (handle "
  -- review_script:7
  local v3: string = d.handle
  parts[#parts + 1] = v3
  parts[#parts + 1] = ")\nTitle: "
  -- review_script:8
  local v4: string = d.title
  parts[#parts + 1] = v4
  parts[#parts + 1] = "\n"
  -- review_script:9
  local v5: string = d.change_source
  parts[#parts + 1] = v5
  parts[#parts + 1] = "\n\nThe caller has made this exact commit available in your local checkout.\nThe checkout that holds the board worktree (`"
  -- review_script:12
  local v6: string = d.board_dir
  parts[#parts + 1] = v6
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it. Your worktree is the only tree.\nReview `"
  -- review_script:15
  local v7: string = d.claim_base
  parts[#parts + 1] = v7
  parts[#parts + 1] = ".."
  -- review_script:15
  local v8: string = d.head_sha
  parts[#parts + 1] = v8
  parts[#parts + 1] = "`; never substitute a branch tip or provider\nstate for either commit. The spec below is authoritative. External checks,\nwhen used, must be inspected by the caller on this exact SHA.\n\n## The spec this PR is supposed to satisfy (verbatim)\n\n---\n"
  -- review_script:22
  local v9: string = d.spec
  parts[#parts + 1] = v9
  parts[#parts + 1] = "\n---\n\n## How to review — a numbered script\n\nThis diff is mechanical: no changed `.tl` file outside `*_test.tl`,\nor fewer than 20 changed lines in total. Four fixed moves, in order:\n\n1. Confirm you are reading exactly `"
  -- review_script:30
  local v10: string = d.head_sha
  parts[#parts + 1] = v10
  parts[#parts + 1] = "`. If the caller supplies\n   external checks, confirm they name that SHA; red or running means stop and\n   record nothing. Never infer check state from the board.\n2. Verify the one measured fact the spec names, against the diff's\n   real effect. A moved number is a finding to quote, not by itself\n   a reason to stop.\n3. Break the guard in a scratch copy: `git show <head>:<file>` the\n   file the diff's own test guards into the scratchpad, mutate the\n   copy (replace a matched needle with unrelated text, flip a\n   boolean — never just reword the text around it), run the diff's\n   own test file against the mutated copy, and watch it refuse.\n4. Record your verdict.\n\nMutation-test at least one guard the change adds or preserves: break\nthe guard in a copy of the file taken with `git show <head>:<path>`,\nnever in a worktree, and confirm the refusal.\n\n## Recording your verdict\n\n`verdict` verifies and records one local commit id. It performs no fetch,\ncredential lookup, check read, merge, or provider write. The caller owns\nthose operations. Read the diff with `git fetch origin <branch>` and `git\nshow <head>:<path>` in the product checkout at `"
  -- review_script:52
  local v11: string = d.product_root
  parts[#parts + 1] = v11
  parts[#parts + 1] = "`; you create\nno worktree. This review is claimed under session `"
  -- review_script:53
  local v12: string = d.review_session
  parts[#parts + 1] = v12
  parts[#parts + 1] = "` — you\nMUST use that exact string. That checkout has no `o/3p` cache yet — run\n"
  -- review_script:55
  local v13: string = d.bootstrap_phrase
  parts[#parts + 1] = v13
  parts[#parts + 1] = "\n\nGitBoard invocation for this review: `"
  -- review_script:57
  local v14: string = d.gitboard_cmd
  parts[#parts + 1] = v14
  parts[#parts + 1] = "` — the exact\nloader and absolute executable the caller runs board commands through.\nUse it verbatim as the prefix below; never guess a product-checkout\nsubstitute of your own, and never bootstrap one yourself.\n\n```\n"
  -- review_script:63
  local v15: string = d.gitboard_cmd
  parts[#parts + 1] = v15
  parts[#parts + 1] = " verdict "
  -- review_script:63
  local v16: string = d.item_id
  parts[#parts + 1] = v16
  parts[#parts + 1] = " accept \\\n  --head "
  -- review_script:64
  local v17: string = d.head_sha
  parts[#parts + 1] = v17
  parts[#parts + 1] = " --session "
  -- review_script:64
  local v18: string = d.review_session
  parts[#parts + 1] = v18
  parts[#parts + 1] = " --repo-dir "
  -- review_script:64
  local v19: string = d.product_root
  parts[#parts + 1] = v19
  parts[#parts + 1] = "\n"
  -- review_script:65
  local v20: string = d.gitboard_cmd
  parts[#parts + 1] = v20
  parts[#parts + 1] = " verdict "
  -- review_script:65
  local v21: string = d.item_id
  parts[#parts + 1] = v21
  parts[#parts + 1] = " request-changes \\\n  --head "
  -- review_script:66
  local v22: string = d.head_sha
  parts[#parts + 1] = v22
  parts[#parts + 1] = " --session "
  -- review_script:66
  local v23: string = d.review_session
  parts[#parts + 1] = v23
  parts[#parts + 1] = " --repo-dir "
  -- review_script:66
  local v24: string = d.product_root
  parts[#parts + 1] = v24
  parts[#parts + 1] = "\n"
  -- review_script:67
  local v25: string = d.gitboard_cmd
  parts[#parts + 1] = v25
  parts[#parts + 1] = " verdict "
  -- review_script:67
  local v26: string = d.item_id
  parts[#parts + 1] = v26
  parts[#parts + 1] = " reject \\\n  --head "
  -- review_script:68
  local v27: string = d.head_sha
  parts[#parts + 1] = v27
  parts[#parts + 1] = " --session "
  -- review_script:68
  local v28: string = d.review_session
  parts[#parts + 1] = v28
  parts[#parts + 1] = " --repo-dir "
  -- review_script:68
  local v29: string = d.product_root
  parts[#parts + 1] = v29
  parts[#parts + 1] = "\n```\n\nRun exactly the one line matching your judgment. The board stores the SHA,\nnot review prose. Put concrete gaps in your final report for the caller. An\naccept does not merge or complete the item; after landing, the caller runs\n`"
  -- review_script:74
  local v30: string = d.gitboard_cmd
  parts[#parts + 1] = v30
  parts[#parts + 1] = " done "
  -- review_script:74
  local v31: string = d.item_id
  parts[#parts + 1] = v31
  parts[#parts + 1] = " --landed SHA`.\n\n## Final report\n\nThe verdict you recorded (or why you could not), the mutation-test\nyou ran and its result, and any concrete findings quoted with\nfile:line. Keep it factual and concise.\n\nA request-changes verdict names five labeled facts, not a fix: the\nexact reproducer; the smallest permitted correction boundary; the\ntempting unsafe repair, when one is visible; the adjacent invariant\nthat repair could violate; and the focused regression plus every\nnamed boundary guard the corrected head must rerun. Do not design\nthe correction: when no safe envelope is established, name the\nuncertainty and let the rework builder bounce rather than widening\nscope to find one.\n"
  return table.concat(parts)
end

return {render = render}
