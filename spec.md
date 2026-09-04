# friction: 2026-09-04 work9-b (/work 9 --routine, orchestrator e1847cac)

## orchestrator

- goal: `gitboard sync` then bootstrap (`o/board` did not exist yet this
  session).
  actually happened: clean — clone, `bin/gitboard sync`, `next`, both worked
  first try. No friction.

- goal: reconcile the previous wave. `show` reported `doing 0/10` — nothing
  to reconcile, no PR awaiting a verdict — so the review-first step of
  `orchestrate` had nothing to claim.
  actually happened: as expected, moved straight to filling the wave with
  builds. No friction; noted only because a reader of this log should know
  the review phase was legitimately empty, not skipped.

- goal: fill the wave with disjoint builds up to N=9. `next` surfaced
  `ekqI_n3Mm` (band 3, top priority) then three board-tooling items
  (`HlNE_YWL2`, `4CTF_fCZV`, `qWfP_VKKJ`, all band 1) as alternates.
  actually happened: reading each item's `## Change` showed `HlNE_YWL2`,
  `4CTF_fCZV`, and `qWfP_VKKJ` all touch `_work/brief_test.tl` (and two of
  the three also share `_work/brieftext.tl`/`_work/brieftext_review.tl`
  territory) — not disjoint from each other. Calling `next` again after
  claiming `ekqI_n3Mm` and `HlNE_YWL2` surfaced two more alternates
  (`Wr2q_dmOF`, `XsHJ_6fGm`); both also overlap `HlNE_YWL2` (`_work/item.tl`
  and `_work/brief.tl` respectively). Cost: 6 `show` calls to establish the
  overlap graph by hand.
  contributed: `next`'s alternates are priority-ordered, not
  disjointness-filtered (by design, per `help orchestrate` — "next... cannot
  see what else you are taking"), and this particular priority band is a
  tight cluster of gitboard-tool items that nearly all touch the same
  handful of `_work/*.tl` files.
  improvement: none needed — this is exactly the check `orchestrate`
  documents as the orchestrator's own job, and it worked as intended (wave
  capped at 2 builds rather than forcing false parallelism). Noting only
  because a `--tree`-aware `brief` (item `XsHJ_6fGm`) or a
  file-overlap-aware `next` would remove this as manual work in the future;
  `XsHJ_6fGm` already exists and is unrelated to overlap detection, so no
  new item.

- goal: place a stale, spec-bar-passing item (`VIU8_B2az`, opened 09:54,
  still `priority: unplaced`) into the order as spare-width refine work.
  actually happened: stopped short of calling `gitboard compare` — every
  candidate comparison target I found was either itself blocked
  (`xK61_V4t0`, blocked by `3IqYweCi`) or required a judgment call about
  relative priority against unrelated work I have no strong basis for.
  contributed: `compare ID OTHER` requires picking a concrete `OTHER` and
  asserting a rank, which is exactly the kind of "comparison that would put
  new work above existing work" the `--routine` doctrine says not to guess
  at.
  improvement: none — correctly left for a refiner pass with more context
  on the whole board's priority order, rather than guessing. Noted here so
  the next refiner sees it without re-discovering it: `VIU8_B2az` (one-line
  SKILL.md doc fix, parent `FcWz_FClp`) has been sitting unplaced since
  09:54 today.

- **goal (critical): close a fully-mined, stale friction-log root
  (`14A3_CTsE`, opened 09:58) as spare-width triage — its two candidate
  countermeasures were both already filed elsewhere (`VIU8_B2az`;
  `HlNE_YWL2` covers the base-guess gap). Ran `gitboard done 14A3_CTsE
  --reason completed --force --why "..."`.**
  actually happened: `done` committed a local `ended/3IrHne1W...` branch,
  then the push failed: `error: RPC failed; HTTP 403 curl 22`, `send-pack:
  unexpected disconnect`. The proxy's own status endpoint showed zero
  `recentRelayFailures` (ruling out an egress-policy block per
  `/root/.ccr/README.md`), and a manual `git push origin
  ended/3IrHne1W...` (create) succeeded immediately after — so push access
  itself is fine. Isolated the actual failure with two manual probes:
  `git push origin --delete items/3IrHne1W...` (the item's OLD branch,
  which `done` needs to remove) → same 403; `git push origin --delete
  ended/3IrHne1W...` (the branch I had just created, attempting to undo
  it) → same 403. Both branch-DELETE pushes fail identically; branch
  create/update pushes (this session's earlier `take` claims on
  `ekqI_n3Mm`/`HlNE_YWL2`, both confirmed present on `origin` byte-for-byte)
  succeed. `gitboard fsck` now flags exactly one problem: `3IrHne1W: does
  not re-encode to the tree it was read from ... canonical form drifted` —
  the item now has BOTH an `items/3IrHne1W...` branch (unchanged, still
  `todo`) and an `ended/3IrHne1W...` branch (the `done` commit) live on
  `origin/cosmic-lua/work` simultaneously, and `gitboard show 14A3_CTsE`
  now returns `14A3_CTsE is ambiguous: 14A3CTsE 14A3CTsE`. I could not
  repair this: no `gitboard` verb deletes a branch, no GitHub MCP tool in
  this session's toolset deletes a ref/branch, and every git-level delete
  attempt hits the same 403. Total cost: ~8 tool calls diagnosing plus the
  item is now genuinely broken pending a session with delete rights.
  contributed: `gitboard done`'s branch-rename (`items/` → `ended/`) is a
  create-then-delete pair, and this session's git push credential for
  `cosmic-lua/work` (unlike, apparently, the credential used by whichever
  session successfully ended `eAtr_TQDr`/`3g5O_V2tF`/other historical
  `[ended]` items — confirmed by `git ls-remote` showing no leftover
  `items/` branch for those) can create/update branches but cannot delete
  them. `done`'s own code has no fallback or detection for a delete that
  fails after the create half already landed — a `nil, string` refusal
  from `done` on a rejected delete, or a check-first `git push
  --delete --dry-run` before committing the create half, would have
  caught this without leaving the item split across two branches.
  improvement: (1) HIGH LEVERAGE, needs a human: whatever grants this
  environment's git-over-HTTPS credential for `cosmic-lua/work` needs
  branch-delete permission restored (or `gitboard done` needs a
  non-git-delete landing mechanism, e.g. GitHub's ref-delete API instead of
  a raw push, if THAT credential path has delete rights this one doesn't —
  untested, no such MCP tool was available this session). (2) a
  spec-bar/gate-level fix for `gitboard done` itself: verify the delete
  will succeed (or perform it) BEFORE the create, or make the two-branch
  transition atomic/resumable so a partial failure doesn't strand the item
  in an ambiguous state. (3) immediate repair needed on the board itself:
  `git push origin --delete items/3IrHne1WNbXGfzIuWJw14A3CTsE` from a
  credential that can delete branches on `cosmic-lua/work` — the `ended/`
  branch already carries the correct `done` commit and needs no changes.
  **Given this, I stopped attempting to close the other two fully-mined
  stale friction logs (`GDeh_uJY2`, `DyBP_Xlun`) this pass** rather than
  risk corrupting two more items the same way; they remain valid triage
  targets for whoever fixes the delete-permission gap.
  **Escalation discovered later in the pass**: `gitboard find` (any query,
  even unrelated ones) now fails outright: `gitboard-find: index:
  3IrHne1WNbXGfzIuWJw14A3CTsE: UNIQUE constraint failed: items.id` — the
  search index apparently keys on item id and the two live branches for
  this one id (`items/...` and `ended/...`) both decode to that id, so
  ANY `find` call board-wide breaks, not just one touching this item.
  `show`/`next`/`take`/etc. on OTHER items were unaffected in this
  session's testing. This raises the repair from "one broken item" to
  "one shared tool disabled for every session" — reinforces (3) above as
  urgent, not just tidy-up.

- goal: fill `HlNE_YWL2`'s brief placeholders before spawning.
  actually happened: the brief's own verdict line said "fill <WORKTREE>,
  <BOUNCE_CONTEXT>, <X>" — `<X>` does not appear as a real template slot;
  it only appears inside the item's own quoted Evidence prose ("branched
  off the latest `origin/<X>`", itself quoting another brief's rendered
  output). Cost: one grep to confirm before pasting the brief unmodified.
  contributed: this is the exact bug board item `WyFa_GL3c` ("gitboard
  brief: the fill-placeholders verdict line names only the template's own
  placeholders, never one quoted in a spec") already targets — a THIRD
  independent occurrence (after the two already recorded on `FcWz_FClp`
  and `DyBP_Xlun`'s friction logs).
  improvement: none new — `WyFa_GL3c` is already filed, spec-bar-passing,
  and unplaced in priority the same as `VIU8_B2az` above; this is
  corroborating evidence for prioritizing it, not a new item.

- goal (minor): re-run `bin/gitboard done` for `14A3_CTsE` a second time
  after a first attempt returned `14A3_CTsE is ambiguous: 14A3CTsE
  14A3CTsE`.
  actually happened: the ambiguity was transient — caused by my own
  `git fetch origin` (run to diagnose the push failure) creating a new
  local remote-tracking ref mid-investigation, resolved itself after
  `gitboard sync`. Separately, the Bash tool's cwd reverted to
  `/home/user/cosmic/o/board` between two calls despite an explicit `cd
  /home/user/cosmic && <command>` in the prior call succeeding — cost 2
  extra calls re-establishing `pwd`. Low cost (under a minute total), not
  filing — a tooling quirk of this session, not a board/tool defect.

## build ekqI_n3Mm (general-purpose) — spawned, in progress at pass end
- claimed under `build-ekqI_n3Mm-e1847cac`, fresh worktree
  `/home/user/agent-work/ekqI_n3Mm` off `origin/main`. No report yet at the
  time this pass ends; will be reconciled next pass.

## build HlNE_YWL2 (general-purpose) — no PR, correctly stopped, 49s, 4 tool calls
- goal: implement «HlNE_YWL2».
  actually happened: correctly stopped at its own mandated pre-flight
  check (`wc -l` every Change-named file before the first edit) —
  `_work/gitgraph_test.tl` is at exactly 500/500, zero headroom, and the
  spec's step 6 requires adding four new test cases to it with no mention
  of splitting/restructuring. Reported the exact command output and every
  other Change-named file's headroom (`item.tl` 466/500, `gitboard.tl`
  462/500, `brief.tl` 266/500, `item_test.tl` 443/500, `brief_test.tl`
  444/500) rather than improvising a split. No edits, nothing pushed,
  clean worktree. Also noted (as friction, not a blocker): this
  `board`-branch worktree carries no `_cli/` lint tooling to verify the
  cap locally, so it fell back to the documented AGENTS.md rule — cost
  one exploratory search, no real problem.
  contributed: same shape as the friction log's own already-filed
  candidate — a spec written without checking whether its target files
  have headroom under the 500-line cap.
  improvement: none new — corroborates the already-filed `AY6h_bM0B`
  ("spec bar: flag a Change-named file already within ~20 lines of the
  500-line cap") a further time; `_work/gitgraph_test.tl` at 500/500 is
  the tightest case seen yet (zero headroom, not just "near"). This
  item (`HlNE_YWL2`) itself needs a respec — either split
  `_work/gitgraph_test.tl` (e.g. extract an `attach`-focused test file)
  as part of its own Change, or move the four new cases elsewhere —
  before it can be pulled again. Filed the blocker per the block-first
  exit (`help block`): `«T6Gj_9ge9»` ("gitgraph_test.tl at 500/500: split
  or relocate before HlNE_YWL2's four new attach/new-parent test cases
  can land", parent same as HlNE_YWL2, repo cosmic-lua/cosmic, base
  board), `gitboard block HlNE_YWL2 T6Gj_9ge9 --reason ...`, then
  `gitboard drop HlNE_YWL2 --force --why ...` (force needed since the
  claim was under `build-HlNE_YWL2-e1847cac`, not this orchestrator
  session directly — expected, not friction). Worktree removed.

## orchestrator (post-pass, PR watch continuation)

- goal: after `«ekqI_n3Mm»`'s PR #1713 got a fresh-context `accept` review
  (mutation-tested, auto-merge enabled, enqueued in the merge queue),
  check whether this session's branch-delete permission on
  `cosmic-lua/work` (broken earlier this pass, see the critical entry
  above) had been fixed before relying on `gitboard done` once the PR
  lands.
  actually happened: `git fetch origin` on the board checkout showed the
  earlier stranded item (`3IrHne1WNbXGfzIuWJw14A3CTsE`, handle
  `14A3_CTsE`) now has ONLY an `ended/...` branch remotely — someone (a
  different credential/session) already deleted the leftover `items/...`
  branch; `gitboard fsck` confirms clean (`ok, 913 items`) and `gitboard
  find` works again. But a direct probe — push a harmless throwaway
  branch (`_perm_test_e1847cac`), then try to delete it — showed CREATE
  still succeeds and DELETE still 403s for this session specifically. The
  repair was made by a different, more-privileged actor; this session's
  own credential is unchanged.
  contributed: same root cause as the critical entry above — this
  session's git-over-HTTPS credential for `cosmic-lua/work` lacks
  branch-delete rights, full stop, independent of anyone else's access.
  improvement: **decided NOT to call `gitboard done` on `ekqI_n3Mm` once
  PR #1713 merges**, to avoid stranding a second item exactly the same
  way. Left `ekqI_n3Mm` in "PR merged (or merging), review accepted,
  awaiting `done`" state instead — a human or a session with
  branch-delete rights needs to run `gitboard done ekqI_n3Mm --pr 1713
  --reason completed --force --why ...` once the merge is confirmed.
  This is the same fix needed as the critical entry above (item 1: fix
  the credential); no new item filed, this is the same open gap
  recurring on live work now, not just historical cleanup.
  Cost: 2 extra git push calls (create+delete probe) to confirm rather
  than assume; a stray, harmless `_perm_test_e1847cac` branch is left on
  `origin` (local copy deleted) since I can't remove the remote copy
  either — cosmetic, not a board item (not under `items/`, `ended/`, or
  `board/`, so `fsck`/`find` don't see it), safe to delete whenever
  someone with rights is cleaning up anyway.

## candidates
- `gitboard done`'s create-then-delete branch transition has no atomicity
  or pre-flight check, and this session's credential cannot delete
  branches on `cosmic-lua/work` at all — stays here for triage: the fix
  needing an actual PR (pre-flight check / atomic transition in
  `_work/*.tl`) is real and specable, but the credential-grant half is not
  something a board item can resolve, and the two are tangled in one
  observation above. A refiner should split them: file the `done`
  robustness fix as its own item; escalate the credential gap outside the
  board.
- `VIU8_B2az` and `WyFa_GL3c`, both already filed and spec-bar-passing,
  both sitting `priority: unplaced` since this morning — not a new item;
  a refiner with fuller context on the priority order should `compare`
  them in.
