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
  local v7: string = d.review_target
  parts[#parts + 1] = v7
  parts[#parts + 1] = "..."
  -- review_script:15
  local v8: string = d.head_sha
  parts[#parts + 1] = v8
  parts[#parts + 1] = "`; never substitute a branch tip or provider\nstate for either commit. The spec below is authoritative. External checks,\nwhen used, must be inspected by the caller on this exact SHA.\n\n## The spec this PR is supposed to satisfy (verbatim)\n\n---\n"
  -- review_script:22
  local v9: string = d.spec
  parts[#parts + 1] = v9
  parts[#parts + 1] = "\n---\n\nFor behavioral fixes, distinguish the reported scenario, the reproduced\ncondition, and the condition repaired. Compare the fixture setup with the\nreported incident: does setup repair or hide the fault before the test?\nCheck that the regression carries the caller's starting state. Work PR194\nfollowed by PR207 shows why: a fetched tracking-ref fixture does not model\na never-fetched clone whose local and tracking refs agree while both are stale.\nIf a nearby defect is repaired but the reported scenario remains unproven,\nreport the change as partial and ask the caller to retain the unresolved\nincident as explicit follow-up work; never silently discharge that scope.\nAn unavailable historical environment need not block a useful bounded fix\nfrom landing with its limitation explicit; it does not prove incident closure.\nThis adds no blanket regression requirement for nonbehavioral edits.\n\n## How to review — a numbered script\n\nThis diff is mechanical: no changed `.tl` file outside `*_test.tl`,\nor fewer than 20 changed lines in total. Four fixed moves, in order:\n\n1. Confirm you are reading exactly `"
  -- review_script:43
  local v10: string = d.head_sha
  parts[#parts + 1] = v10
  parts[#parts + 1] = "`. If the caller supplies\n   external checks, confirm they name that SHA; red or running means stop and\n   record nothing. Never infer check state from the board.\n2. Verify what the spec names against the diff's real effect. A moved\n   number alone is no reason to stop. When this changes a behavioral guard,\n   before reading the builder's test rationale, derive a plausible failure\n   case from the supplied problem, full spec and parent outcome; compare it\n   with the actual fixtures, setup steps, exclusions and assertions. Report\n   missing material parent context as uncertainty. Where material uncertainty\n   remains, run one focused discriminating check and report whether the\n   reported scenario is covered or remains unresolved. Keep findings about\n   the requested outcome and within the permitted correction boundary.\n   Mutating an existing assertion alone does not challenge its acceptance\n   model. Keep relevant evidence available. No extra round, full gate or second\n   mutation is mandatory;\n   the same focused check may also satisfy move 3. A pure rename or pin-only\n   change requires no invented counterexample.\n3. Break the guard in a scratch copy: `git show <head>:<file>` the\n   file the diff's own test guards into the scratchpad, mutate the\n   copy (replace a matched needle with unrelated text, flip a\n   boolean — never just reword the text around it), run the diff's\n   own test file against the mutated copy, and watch it refuse.\n4. Record your verdict.\n\nMutation-test at least one guard the change adds or preserves: break\nthe guard in a copy of the file taken with `git show <head>:<path>`,\nnever in a worktree, and confirm the refusal.\nFor generated code, mutate the SOURCE, never the artifact: if the build\nrewrites your edit, you mutated an output. A green build that regenerated\naway the mutation is INCONCLUSIVE. After a source mutation, the first\ngenerator refusal is not a catch: rerun after regeneration until the named\ntest assertion actually fails; a generator/build refusal does not count.\n\n## Recording your verdict\n\nYou do not run `verdict` — no spawned agent runs a board verb. The caller\nrecords your verdict with `verdict ID KIND --head SHA --session S`, which\nverifies and records one local commit id. It performs no fetch,\ncredential lookup, check read, merge, or provider write. The caller owns\nthose operations, and so does watching them: never poll or subscribe to a\nprovider event yourself. Read the diff with `git fetch origin <branch>` and\n`git show <head>:<path>` in the product checkout at `"
  -- review_script:84
  local v11: string = d.product_root
  parts[#parts + 1] = v11
  parts[#parts + 1] = "`; you\ncreate no worktree. This review is claimed under session `"
  -- review_script:85
  local v12: string = d.review_session
  parts[#parts + 1] = v12
  parts[#parts + 1] = "`\n— you MUST use that exact string. If this checkout has no `o/3p` cache yet, run\n"
  -- review_script:87
  local v13: string = d.bootstrap_phrase
  parts[#parts + 1] = v13
  parts[#parts + 1] = "\n\nYour final report carries exactly one verdict line, in this fixed envelope,\nand your findings follow it:\n\n```\nverdict: accept|request-changes|reject head="
  -- review_script:93
  local v14: string = d.head_sha
  parts[#parts + 1] = v14
  parts[#parts + 1] = " session="
  -- review_script:93
  local v15: string = d.review_session
  parts[#parts + 1] = v15
  parts[#parts + 1] = "\n```\n\nWrite exactly the one kind matching your judgment. The board stores the SHA,\nnot review prose. Put concrete gaps in your final report for the caller. An\naccept does not merge or complete the item; after landing, the caller runs\n`done "
  -- review_script:99
  local v16: string = d.item_id
  parts[#parts + 1] = v16
  parts[#parts + 1] = " --landed SHA`.\n\n## Final report\n\nThe verdict you recorded (or why you could not), the mutation-test\nyou ran and its result, and any concrete findings quoted with\nfile:line. Keep it factual and concise.\n\nA request-changes verdict names five labeled facts, not a fix: the\nexact reproducer; the smallest permitted correction boundary; the\ntempting unsafe repair, when one is visible; the adjacent invariant\nthat repair could violate; and the focused regression plus every\nnamed boundary guard the corrected head must rerun. Do not design\nthe correction: when no safe envelope is established, name the\nuncertainty and let the rework builder bounce rather than widening\nscope to find one.\n"
  return table.concat(parts)
end

return {render = render}
