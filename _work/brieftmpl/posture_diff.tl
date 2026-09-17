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
  parts[#parts + 1] = "), not the suite —\nrestore it exactly. For generated code, mutate the SOURCE, never the\nartifact: if the build rewrites your edit, you mutated an output. A\ngreen build that regenerated away the mutation is INCONCLUSIVE. After\na source mutation, the first generator refusal is not a catch: rerun\nafter regeneration until the named test assertion actually fails; a\ngenerator/build refusal does not count. A real break changes the\noutcome the test reads, never just the text around it: replace a\nmatched needle with unrelated text rather than extending it, flip a\nboolean rather than renaming it, and if the test stays green the guard\nis decoration.\nDo this from your own fresh checkout at `"
  -- posture_diff:45
  local v3: string = d.worktree
  parts[#parts + 1] = v3
  parts[#parts + 1] = "` — never reuse\nanother agent's worktree.\nThe checkout that holds the board worktree (`"
  -- posture_diff:47
  local v4: string = d.board_dir
  parts[#parts + 1] = v4
  parts[#parts + 1] = "/..`) is the\norchestrator's and is stale by construction; never read, grep or build\nin it. Your worktree is the only tree.\n\n## Recording your verdict\n\nYou do not run `verdict` — no spawned agent runs a board verb. The caller\nrecords your verdict with `verdict ID KIND --head SHA --session S`, which\nverifies and records one local commit id. It performs no fetch,\ncredential lookup, check read, merge, or provider write. The caller owns\nthose operations, and so does watching them: never poll or subscribe to a\nprovider event yourself. This review is claimed under session `"
  -- posture_diff:58
  local v5: string = d.review_session
  parts[#parts + 1] = v5
  parts[#parts + 1] = "` —\nyou MUST use that exact string. If this checkout has no `o/3p` cache yet, run\n"
  -- posture_diff:60
  local v6: string = d.bootstrap_phrase
  parts[#parts + 1] = v6
  parts[#parts + 1] = "\n\nYour final report carries exactly one verdict line, in this fixed envelope,\nand your findings follow it:\n\n```\nverdict: accept|request-changes|reject head="
  -- posture_diff:66
  local v7: string = d.head_sha
  parts[#parts + 1] = v7
  parts[#parts + 1] = " session="
  -- posture_diff:66
  local v8: string = d.review_session
  parts[#parts + 1] = v8
  parts[#parts + 1] = "\n```\n\nWrite exactly the one kind matching your judgment. The board stores the SHA,\nnot review prose. Put concrete gaps in your final report for the caller. An\naccept does not merge or complete the item; after landing, the caller runs\n`done "
  -- posture_diff:72
  local v9: string = d.item_id
  parts[#parts + 1] = v9
  parts[#parts + 1] = " --landed SHA`.\n\n## Final report\n\nThe verdict you recorded (or why you could not), the mutation-test\nyou ran and its result, and any concrete findings quoted with\nfile:line. Keep it factual and concise.\n"
  return table.concat(parts)
end

return {render = render}
