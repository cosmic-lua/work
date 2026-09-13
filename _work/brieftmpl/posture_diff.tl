local briefctx = require("_work.briefctx")

local function render(d: briefctx.PostureDiff): string
  local parts: {string} = {}
  parts[#parts + 1] = "## How to review — the posture is ADVERSARIAL\n\nYour job is to try to make this diff fail, not to confirm it looks\nfine.\n\n1. Confirm you are reading exactly `"
  -- posture_diff:6
  local v1: string = d.head_sha
  parts[#parts + 1] = v1
  parts[#parts + 1] = "`. If the caller supplies\n   external checks, confirm they name that SHA; red or running means stop and\n   record nothing. Never infer check state from the board. The caller spawns\n   this review only once mechanical checks are green on this exact head (or,\n   when CI was unavailable by the item's own design, once the caller ran the\n   spec-named guards locally instead) — trust that gate; your job is the\n   fresh semantic read and mutation below, not re-verifying CI.\n2. The diff is the Change — everything present, nothing extra. List\n   the changed files and confirm each is inside the spec's stated\n   scope. Anything outside it is scope creep — quote it, even when\n   it looks good; good ideas become their own items. When the spec\n   states a pattern and a count, re-run `cosmic --find` on the handed-over\n   commit from your checkout: the hit list IS the expected change\n   set — a hit the diff leaves unchanged, or a changed site outside\n   the hits, is a finding.\n3. The walls held: every `## Non-goals` line honored, frozen\n   contracts unmoved.\n4. Conventions hold: the repo's AGENTS.md binds. Anything a gate\n   should have caught but did not is itself a finding to report.\n5. It serves the outcome: judge the diff against the item's parent\n   chain, not just the letter of `## Change`. A green gate on a\n   change that misses the point means the SPEC was wrong — say so,\n   never wave the diff through.\n6. It is the least thing: name any surplus concretely and treat it\n   as a gap to quote.\n\nMutation-test at least one guard the change adds or relies on: break\nwhat it guards, confirm the diff's own test catches it — run the ONE\ntest file that guards it ("
  -- posture_diff:34
  local v2: string = d.test_cmd_phrase
  parts[#parts + 1] = v2
  parts[#parts + 1] = "), not the suite —\nrestore it exactly. A real break changes the outcome the test reads,\nnever just the text around it: replace a matched needle with\nunrelated text rather than extending it, flip a boolean rather than\nrenaming it, and if the test stays green the guard is decoration.\nDo this from your own fresh checkout at `"
  -- posture_diff:39
  local v3: string = d.worktree
  parts[#parts + 1] = v3
  parts[#parts + 1] = "` — never reuse\nanother agent's worktree.\nThe checkout that holds the board worktree (`"
  -- posture_diff:41
  local v4: string = d.board_dir
  parts[#parts + 1] = v4
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it. Your worktree is the only tree.\n\n## Recording your verdict\n\n`verdict` verifies and records one local commit id. It performs no fetch,\ncredential lookup, check read, merge, or provider write. The caller owns\nthose operations. This review is claimed under session `"
  -- posture_diff:49
  local v5: string = d.review_session
  parts[#parts + 1] = v5
  parts[#parts + 1] = "` —\nyou MUST use that exact string. That checkout has no `o/3p` cache yet — run\n"
  -- posture_diff:51
  local v6: string = d.bootstrap_phrase
  parts[#parts + 1] = v6
  parts[#parts + 1] = "\n\nGitBoard invocation for this review: `"
  -- posture_diff:53
  local v7: string = d.gitboard_cmd
  parts[#parts + 1] = v7
  parts[#parts + 1] = "` — the exact\nloader and absolute executable the caller runs board commands through.\nUse it verbatim as the prefix below; never guess a product-checkout\nsubstitute of your own, and never bootstrap one yourself.\n\n```\n"
  -- posture_diff:59
  local v8: string = d.gitboard_cmd
  parts[#parts + 1] = v8
  parts[#parts + 1] = " verdict "
  -- posture_diff:59
  local v9: string = d.item_id
  parts[#parts + 1] = v9
  parts[#parts + 1] = " accept \\\n  --head "
  -- posture_diff:60
  local v10: string = d.head_sha
  parts[#parts + 1] = v10
  parts[#parts + 1] = " --session "
  -- posture_diff:60
  local v11: string = d.review_session
  parts[#parts + 1] = v11
  parts[#parts + 1] = " --repo-dir "
  -- posture_diff:60
  local v12: string = d.worktree
  parts[#parts + 1] = v12
  parts[#parts + 1] = "\n"
  -- posture_diff:61
  local v13: string = d.gitboard_cmd
  parts[#parts + 1] = v13
  parts[#parts + 1] = " verdict "
  -- posture_diff:61
  local v14: string = d.item_id
  parts[#parts + 1] = v14
  parts[#parts + 1] = " request-changes \\\n  --head "
  -- posture_diff:62
  local v15: string = d.head_sha
  parts[#parts + 1] = v15
  parts[#parts + 1] = " --session "
  -- posture_diff:62
  local v16: string = d.review_session
  parts[#parts + 1] = v16
  parts[#parts + 1] = " --repo-dir "
  -- posture_diff:62
  local v17: string = d.worktree
  parts[#parts + 1] = v17
  parts[#parts + 1] = "\n"
  -- posture_diff:63
  local v18: string = d.gitboard_cmd
  parts[#parts + 1] = v18
  parts[#parts + 1] = " verdict "
  -- posture_diff:63
  local v19: string = d.item_id
  parts[#parts + 1] = v19
  parts[#parts + 1] = " reject \\\n  --head "
  -- posture_diff:64
  local v20: string = d.head_sha
  parts[#parts + 1] = v20
  parts[#parts + 1] = " --session "
  -- posture_diff:64
  local v21: string = d.review_session
  parts[#parts + 1] = v21
  parts[#parts + 1] = " --repo-dir "
  -- posture_diff:64
  local v22: string = d.worktree
  parts[#parts + 1] = v22
  parts[#parts + 1] = "\n```\n"
  return table.concat(parts)
end

return {render = render}
