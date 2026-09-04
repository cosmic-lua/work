# friction: 2026-09-04 work9-c (/work 9 --routine)

## orchestrator
- goal: follow the doctrine's log-opening order (open the log after bootstrap+sync, before the
  first verb that selects work) exactly.
  actually happened: ran `sync`, `show`, and `next` (one call each) before opening this log —
  `next` is a work-selecting verb, so the log should have preceded it. No board mutation
  resulted from the misordering (all three calls are read-only), so no work was lost, but it
  is itself a friction instance: a first-time router of this pass had to read `friction.md` in
  full to learn the ordering rule, and by then the read-only reconnaissance calls (sync/show/next)
  had already run once to orient.
  contributed: `skills/work/SKILL.md`'s `--routine` section lists the friction-log steps
  inline but doesn't flag that `next` itself counts as "a verb that selects work" until
  friction.md's own log-file preamble is read; the ordering constraint lives one hop away
  from the step list that names it.
  improvement: doc — restate "next counts as work-selecting; don't call it before opening the
  log" directly in `skills/work/SKILL.md`'s `--routine` friction bullet, not only in
  friction.md's file-naming aside. Doesn't pass the spec bar as a standalone item (too small,
  no measured command, prose-only), so it stays here for triage.

- goal: claim and brief «lER0_dvnI» (gitboard verdict/take auto-rebase-retry) as a normal
  builder item off `main`.
  actually happened: `brief builder lER0_dvnI` emitted a worktree instruction of "branched
  off the latest origin/main" and "Open a PR from 3IqbI4Uf to main", but the item's own
  spec is entirely about `_work/*.tl` (gitboard's own source), which exists ONLY on the
  `board` branch of cosmic-lua/cosmic (confirmed: `git clone --branch main` has no `_work/`
  directory at all). `show lER0_dvnI` had no `base:` field printed and no `set ... base`
  line in its commit history, unlike sibling items WQjH_vI9p/4mpH_hi6v which both had an
  explicit `set ... base` commit recording `base: board`. Had I claimed and spawned the
  builder as briefed, it would have bootstrapped on `main`, found no `_work/` tree, and
  burned a full agent spawn (and a respawn cycle) discovering the mismatch itself — instead
  caught in ~2 read-only calls (`show`, then a 15s branch/ls check) before any claim or
  spawn.
  contributed: whoever filed `lER0_dvnI` omitted `--base board` at `new` time (no such
  omission on the two sibling `_work/*.tl` items filed the same day), and `brief builder`
  has no cross-check that the base branch it is about to hand a builder actually contains
  the paths the spec names.
  improvement: gate — `gitboard new`/`brief builder` could refuse (or at least warn) when
  none of a spec's own backtick-quoted paths exist on the resolved base branch; short of
  that, `brief`'s own doc should note that a `_work/*.tl`-only spec with no explicit base
  is very likely missing `--base board`. Applied the cheap fix myself as orchestrator:
  `gitboard set lER0_dvnI --base board` (repair, not a build) before claiming.

- goal: claim «4CTF_fCZV» (gitboard brief review base-branching fix) and «gj7P_Db0H» (gitview
  queued-accept wiring), both about `_work/*.tl`-only surface.
  actually happened: same defect as «lER0_dvnI» above, twice more: `take 4CTF_fCZV` actually
  minted a claim ("branch 3IreoUxF off main") before I caught it — one wasted take/drop round
  trip (drop + re-brief needed) versus catching it in `show` first as I'd started doing for
  the third instance. `show` for `4CTF_fCZV` and `gj7P_Db0H` both had no `base:` line and no
  `set ... base` commit, exactly like `lER0_dvnI`. Three of the ~7 items surfaced by `next`
  this pass shared the identical missing-base defect — no longer an isolated slip.
  contributed: none of these three items' specs mention `board` or `main` explicitly (unlike
  the two that DID set base correctly, both of which say "board" plainly in their own text) —
  the person/agent filing an item with `new` has no prompt or reminder to set `--base board`
  for a `_work/*.tl`-scoped spec, and `new`'s own help text doesn't call out that a repo's
  default base may be wrong for a subtree that only exists on a non-default branch.
  improvement: gate — `gitboard new` should default `--base` from the CALLER's own current
  branch/worktree base when the title or spec's first code-path reference resolves to a path
  absent from the repo's configured default base, or at minimum refuse silently-defaulted
  bases and require `--base` to be explicit whenever `repo` is `cosmic-lua/cosmic` (which has
  two live bases, `main` and `board`) — every other repo in scope has exactly one. Filed as
  its own item below (passes the bar: concrete file, concrete command, concrete fix).

- goal: fill the wave with disjoint pullable items; `next` offered «WQjH_vI9p` ("review brief:
  the accept-landing instruction says 'never merge directly' unconditionally...") and, three
  claims later, «4CTF_fCZV» ("gitboard brief review: branch accept-landing instructions on the
  item's base").
  actually happened: both target the identical fix — `_work/brieftext_review.tl`'s "Recording
  your verdict" section branching on `base` — confirmed by reading both specs in full (`show`
  x2, ~1 minute). «4CTF_fCZV»'s spec is strictly the superset: three corroborating incident
  reports plus the `merge_method: squash` gap `WQjH_vI9p` never mentions. Had both been built
  in parallel (already claimed «WQjH_vI9p» under `build-WQjH_vI9p-62aa6405` before noticing),
  the two PRs would have raced on the same ~5-line section of a 217-line file, and I'd have
  discovered it only at merge time on whichever landed second. Caught before any spawn: one
  `drop` + `done --force --why` round trip (2 calls) to close `WQjH_vI9p` as not-planned, no
  agent time spent.
  contributed: nothing in `next`'s ranking flags that two todo items describe the same
  underlying bug — it ranks by priority band, not by content similarity, and content
  similarity is exactly what `new`'s own dedup check (the "similar: ..." lines it printed when
  I later filed a genuinely new item) already does at FILE time but `next`/`take` never
  re-checks at PULL time, by which point two items can have drifted apart in the interim (as
  these two did — «4CTF_fCZV» was filed 3 hours after «WQjH_vI9p», already citing new
  corroborating evidence the older item never got).
  improvement: `next`/`take`'s existing dedup signal (whatever `new` already runs against
  the corpus) is the leverage point — surfacing "N similar items" the way `new` does, at
  `next`/`take` time too, would have caught this before any claim. Short of that: a periodic
  refine pass that re-runs `new`'s own similarity check across all open todo pairs and files
  `compare`/attach-as-duplicate decisions is the manual substitute. Not filed as its own item
  this pass — no time to read the dedup implementation closely enough to write a bar-passing
  spec for surfacing it at `next` time; stays here for the next refiner to pick up.

## candidates
- (see orchestrator entry 1 above, the next-before-log-open ordering note) — stays here for
  triage: too small/prose-only to file as its own spec-bar-passing item.
- (see orchestrator entry 4, the missing-`--base`-at-`new`-time gap) — filed as «4Ssv_dl3S»
  ("gitboard new: accept --base at file time instead of requiring a follow-up set").
- (see orchestrator entry 5, dedup blind spot between `next`/`take` and `new`'s own similarity
  check) — stays here for triage: needs a read of the dedup implementation this pass didn't
  have time for, to write a spec concrete enough to pass the bar.

## refine T6Gj_9ge9 (claude, sonnet) — spec rewritten, 383s, 27 tool calls, ~1.9M tokens (cache-heavy)
- goal: rewrite the item's `## Change` into a literal, bar-passing instruction (see the
  refine brief's own gap statement).
  actually happened: succeeded — `gitboard-spec: 3IshlsZJ's spec replaced`. Two errors en
  route (both self-recovered, no wasted work beyond the retry): `o/bin/gitboard` missing at
  first (`sync` failed exit 127, brief wrongly asserted it was pre-built — agent ran
  `bin/cosmic --make build` itself, ~1 extra call), and the first `spec` write attempt
  omitted `--session`, refused with the exact claim-string message (~1 extra call). First
  edit at call 24 of 27 — almost the whole budget was reading/deciding, matching a refine
  task's shape.
  contributed: the brief's own "gitboard is already built in the board checkout" assertion
  was stale for this worktree.
  improvement: covered by this log's orchestrator-ordering candidate above (brief text
  should say "build it if missing," not assert it exists) — folds into that same triage
  candidate, not a new one.
  NOTE (found after this agent reported): the item was later discovered to be targeting the
  wrong repository entirely (`cosmic-lua/cosmic@board`, stale — see the post-pass correction
  section) and its claim was dropped for a re-pull against `cosmic-lua/work`. Spot-checked
  the rewritten spec against the real tree: it held verbatim (same function names, same
  line numbers) — the agent's actual analysis work was not wasted, only its claim.

## build lER0_dvnI (claude, sonnet) — stopped short, 401s, 27 tool calls, ~1.6M tokens
- goal: implement bounded fetch+rebase+retry in `gitboard verdict`/`take`.
  actually happened: correctly stopped — traced the spec's verb names to their implementing
  files (~10 calls, no file names in the spec itself), then found the safe fix requires
  re-running the whole verb's gates on retry (read from `publish.tl`/`gitgate.tl` doc
  comments), which needs a line `_work/gitverbs.tl` (500/500, exact cap) cannot hold. Zero
  errors; one incidental non-fatal `ls`/`cat` probe returned exit 2 (file didn't exist,
  expected).
  contributed/improvement: same file-cap class as `zq2b_vYsf`/`T6Gj_9ge9`, IN THE STALE
  TREE. Retargeted to `cosmic-lua/work`, whose real `_work/gitverbs.tl` is 494/500 (6 lines
  headroom, not 0) and `_work/gitgate.tl` 382/500 (118 lines headroom) — this blocker may
  not even exist in the real tree; left for a fresh pull to re-measure rather than guessed
  at here.

## build 4mpH_hi6v (claude, sonnet) — killed mid-flight, ~512s before stop, 81 tool calls, ~7.9M tokens
- goal: implement `gitboard brief --out FILE`.
  actually happened: stopped by the orchestrator (`TaskStop`) once the stale-repo problem
  was confirmed, mid-review of its own diff, one edit-string mismatch en route (a stale
  multi-line string in an `Edit` call against `_work/gitboard.tl`, ~1 wasted call, easily
  recovered) and heavy repeated re-reads of the same handful of files while iterating
  (`brief.tl` x11, `brief_test.tl` x8) — normal edit-verify-reread cycling, not a sign of
  confusion. No commit was ever made (worktree had only uncommitted changes at kill time);
  discarded with the worktree.
  contributed: wrong repo (`cosmic-lua/cosmic@board`, stale), caught before any push.
  improvement: none for the agent's own conduct; covered by the systemic fix.

## build 4CTF_fCZV (claude, sonnet) — killed mid-flight, ~509s before stop, 61 tool calls, ~5.9M tokens
- goal: branch the review-brief accept-landing text on the item's `base`.
  actually happened: implemented, gated, committed locally (1 commit, unpushed) before the
  orchestrator stopped it. One format-check failure en route (`_work/brieftext_review.tl`
  format mismatch, ~1 extra `--check fmt`/fix cycle) — ordinary iteration.
  contributed: wrong repo, caught after commit but before push — no PR opened, no history
  published anywhere. Worktree and branch discarded.
  improvement: none for the agent's own conduct; covered by the systemic fix.

## build gj7P_Db0H (claude, sonnet) — completed, PR opened then closed, 428s, 70 tool calls, ~5.9M tokens
- goal: wire `queue_states` into `gitview.tl`'s live `next` path.
  actually happened: fully implemented, gated green (426 tests), mutation-tested, and
  opened PR #1716 against `cosmic-lua/cosmic`'s `board` branch — READY, correctly formed
  (`Board:` first line, right base, right diff scope). The only agent in this wave to reach
  a real PR before the stale-repo problem surfaced. Zero errors in its own run; the repeated
  file reads (`gitview.tl` x9, `gitview_test.tl` x8, plus 3 restores from a `.bak` copy
  during its mutation test) are the mutation-test-and-restore cycle working as intended.
  contributed: wrong repo — the PR could never have shipped regardless of code quality,
  since only `cosmic-lua/work@main` feeds a gitboard release. This is the single most
  expensive instance of the systemic finding: a fully "successful" agent run, wasted end to
  end, plus the orchestrator's own cost to notice, comment, and close the PR after the fact.
  improvement: covered by the systemic fix (filed «DUkw_bCrv») — this is the entry that
  makes the case for (a), deleting the branch outright, over (b), a README note alone: a
  README does not stop a builder mid-diff from finishing and opening a PR against tree
  content it already has checked out; only removing the branch (or a `gitboard`-level
  refusal on `--repo cosmic-lua/cosmic --base board`) would have caught this before the
  agent ever started, not just before the orchestrator noticed.

## build zq2b_vYsf (claude, sonnet) — stopped short, 88s, 11 tool calls, ~343k tokens (cache-heavy)
- goal (agent's, quoted from its report): implement the minted-claimant refusal-text change in
  `_work/gitverbs.tl` (drop) and the moved-to `_work/gitgate.tl` (spec).
  actually happened: correctly stopped per its brief's own step 1 — both target files measured
  at exactly 500/500 lines before any edit, and the Change's two new refusal-message branches
  are genuine net-new lines that cannot fit. `cosmic _tool/friction.tl` on its transcript:
  events=45, tool_calls=11 (Bash=3, Grep=4, Read=4), wall=88s, tokens in=14/out=28/
  cache_read=309945/cache_create=33138, first edit: none, zero errors, zero repeated commands
  — a clean, efficient stop with no wasted motion.
  contributed: the spec's own `## Evidence` guessed the `spec` refusal lived in
  `_work/gitverbs.tl` or `_work/gitclaim.tl`; it had since moved to `_work/gitgate.tl` (one
  extra grep, ~1 tool call, to relocate it — cheap, and exactly the "moved number, not a
  shape change" case the brief tells builders to just re-verify and continue past).
  improvement: none needed for the agent's own conduct — this is the same class of gap
  «T6Gj_9ge9» already exists to fix a sibling instance of (files nearing/at the 500-line cap
  discovered only at build time). Reconciled per `help drop`'s own rule (never bare-drop an
  item that cannot proceed): filed «6ImQ_qAgC» ("gitverbs.tl/gitgate.tl at 500/500: split or
  relocate before zq2b_vYsf's minted-claimant refusal text can land"), `block`ed «zq2b_vYsf»
  on it (which released the claim as a side effect — a bare `drop` after `block` correctly
  refused with "not in flight"), and removed the now-unneeded worktree/branch.

## orchestrator (post-pass correction, prompted by the user)
- goal: the user asked whether items scoped to "board" should be checked against
  `cosmic-lua/work` and have their repo/base updated if stale.
  actually happened: this pass had already built worktrees, and one agent (`gj7P_Db0H`)
  had already opened a real, green-CI PR (#1716), against `cosmic-lua/cosmic`'s `board`
  branch — which turned out to be a STALE, superseded fork of the gitboard tool's source
  from before it was extracted into its own repository, `cosmic-lua/work` (confirmed:
  `cosmic-lua/work`'s `_work/` has 111 files including an entire git-ref-based
  storage/SQL-cache layer `board`-branch's 81-file `_work/` lacks entirely, and
  `bin/gitboard.pin`'s own comment states only pushes to `cosmic-lua/work`'s `main`
  publish releases). Cost: PR #1716 closed (would never have shipped regardless of
  correctness); 2 more agents (`4mpH_hi6v`, `4CTF_fCZV`) stopped mid-flight via `TaskStop`
  before push (one had committed locally, unpushed — discarded with its worktree);
  `lER0_dvnI` and `T6Gj_9ge9`'s claims dropped and re-pointed. Total: ~5 wasted agent runs
  (this pass's own wave) plus a systemic backlog of 21 open items across (at least) two
  sessions carrying the same wrong `target` field, one (`4URu_CfFY`) independently
  discovered and only half-fixed by a PRIOR session before this one.
  contributed: nothing in `next`/`take`/`brief` cross-checks a `repo`/`base` pair against
  which repository `bin/gitboard.pin` actually ships releases from — an item can be filed,
  pulled, briefed, built, gated green, and landed as a real PR entirely inside one wrong
  but internally-consistent repo, with no signal anywhere in that chain that the repo itself
  is the error. `gitboard help`'s own topics never mention `cosmic-lua/work` by name to an
  orchestrator working `cosmic-lua/cosmic`-repo items, so nothing prompted a cross-check
  even though this session's own bootstrap (`git clone https://github.com/cosmic-lua/work
  o/board`) was ALREADY using the correct repo for board STATE the entire time — only the
  item `target` fields (for board TOOL SOURCE) were wrong.
  improvement: filed «DUkw_bCrv» ("cosmic-lua/cosmic's board branch is a stale predecessor
  of cosmic-lua/work: mark or remove it") — delete or loudly mark the stale branch as the
  mechanical fix; a `gitboard new`/`set` refusal on `--repo cosmic-lua/cosmic --base board`
  pointing at `cosmic-lua/work` instead would close this permanently. Retargeted all 21
  affected open items (`gitboard set ID --repo cosmic-lua/work --base main`) this session;
  spot-checked one (`T6Gj_9ge9`'s rewritten spec) against the real `cosmic-lua/work` tree
  and found its analysis held verbatim (same test function names, same line numbers,
  `_work/gitattach_test.tl` still free) — the two trees have NOT diverged in already-shared
  files, only grown new ones in `cosmic-lua/work`, so most of the 21 retargeted items likely
  need no further respec beyond what a builder's normal step-1 re-measurement already does.

## ledger
- claimed and spawned «T6Gj_9ge9», «lER0_dvnI», «4mpH_hi6v», «4CTF_fCZV», «gj7P_Db0H» as a
  wave of builders/refiner, each after repairing a missing/wrong `base`/`repo` field —
  ALL FIVE later found to be pointed at the wrong repository entirely (see the post-pass
  correction section below) and unwound: claims dropped, worktrees/branches removed, one
  real PR (#1716, «gj7P_Db0H») closed unmerged
- closed «WQjH_vI9p» not-planned (duplicate of «4CTF_fCZV», force + why) — this one stays
  closed; the duplicate finding was independent of the repo error
- claimed «zq2b_vYsf» as build-zq2b_vYsf-62aa6405 (drop/spec refusal text fix); stopped
  short (both target files at the 500-line cap IN THE STALE TREE — headroom differs in the
  real tree, see below) — filed «6ImQ_qAgC» as its blocker, `block`ed it, claim released
- filed «4Ssv_dl3S» (gitboard new --base at file time) as a bar-passing countermeasure —
  itself also mis-targeted at file time (repo cosmic-lua/cosmic, no base) and retargeted
- filed «6ImQ_qAgC» (gitverbs.tl/gitgate.tl split decision) as zq2b_vYsf's blocker
- filed «DUkw_bCrv» ("cosmic-lua/cosmic's board branch is a stale predecessor of
  cosmic-lua/work: mark or remove it") — the systemic fix
- retargeted 21 open items total (`gitboard set ID --repo cosmic-lua/work --base main`):
  every item this pass touched above, plus 15 pre-existing ones this pass discovered
  carrying the identical stale `target`, including «4URu_CfFY» — a PRIOR session's item
  that hit the same confusion independently and only half-resolved it
- this log filed as «<friction-handle>» (see pass report)
