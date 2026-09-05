# friction: 2026-09-05 work9 (/work 9 --routine)

## orchestrator
- goal: bootstrap and reconcile per `orchestrate` steps 1-2. `show` at
  pass start: `doing 0/10`, `todo 202 (0 pullable)`, `triage 1` — a
  friction log (`5BNQ_dnD4`) left over from an already-fully-reconciled
  prior pass by this same session (its own countermeasures already
  resolved or held for triage, both its spawned builds merged and
  `done`). Nothing to reconcile in `doing`; triaged the leftover log
  with `done 5BNQ_dnD4` (`resolution: completed`), matching the
  precedent of two prior same-shaped logs (`HWDX_5ZOC`, `n9ol_RmUm`)
  closed the same way once mined. No cost beyond the one `done` call —
  noted only because it consumed this pass's whole "triage what
  arrived" step before any refine/build could start.
- goal: act on `next`'s recommendation (per `system`'s "beyond the
  queue" order). `next` named `vCsZ_TzIP` — a fully-evidenced,
  gate-green item permanently stuck on "no session in this environment
  has cross-org GitHub access to teal-language/tl", already blocking
  one dependent, already flagged in the now-closed prior log as a wall
  refining again would not inform. Confirmed the wall still holds
  (this session's own GitHub scope is `cosmic-lua/cosmic`,
  `cosmic-lua/cosmopolitan`, `cosmic-lua/work` only) and moved past it
  without spending a refine action re-deriving the same conclusion —
  second pass in a row doing this. Candidate below.
- goal: refine the next-highest bar-failing item instead. Skipped
  `uS5o_Bw1b` (container-covariance, 9 sites) on inspection: its
  Change would end in the same "carried tl patch → needs a
  teal-language/tl issue" shape as `vCsZ_TzIP`/`FePr_L4FB` — pulling it
  risks a full refine+build+review cycle that lands on the identical
  wall at the handover step. Picked `mEBx_YKCA` instead (a pure
  in-tree doc fix, no upstream dependency): wrote its `## Change` (add
  a `## reads-declaration` section to `docs/guides/lint.md`), verified
  by building `o/bin/cosmic` fresh (`bin/cosmic --make fetch && --make
  build`, ~90s) and running `o/bin/cosmic --check lint` against a
  hand-written fixture to capture the exact diagnostic text rather
  than transcribe it from source — the item's OWN stale fact (`wc -l
  docs/guides/lint.md` was 353 at filing, 2026-08-28; a sibling item
  landed since and it is 419 now, still 81 lines under the cap) got
  corrected in the same refine rather than carried forward. `spec
  mEBx_YKCA` accepted; `show` confirmed no remaining `bar:` line.
- goal: fill the wave (`orchestrate` step 4) with the now-pullable
  `mEBx_YKCA`. `show` (board overview) still reported `todo 202 (0
  pullable)` after a `sync`, and `next` still recommended refining the
  (already-triaged-as-a-wall) `vCsZ_TzIP` instead of naming
  `mEBx_YKCA` as buildable. A direct `take mEBx_YKCA` succeeded
  immediately ("3IYTD6Mm is yours"), confirming the board-overview
  count and `next` were both stale while `take` read live state
  correctly — the EXACT shape the prior pass's own (now-closed)
  friction log flagged and explicitly held back from filing, pending
  "a repro from someone with gitboard source access." This session
  has that access (`GITBOARD_DIR` is a `cosmic-lua/work` checkout) and
  now has the repro: traced it as far as `_work/gitview.tl:250`'s
  digest-gated sqlite cache (`_work/cache.tl:196`) versus
  `_work/gitspec.tl`'s `spec` verb, which commits the new spec to the
  item's ref and touches no cache file at all — the next `open()`
  should see the ref's changed SHA and rebuild, and across a `sync`
  plus two `show`s it did not. Filed as `Vahb_Krg9` under the flow-
  system root (`i2De_o66q`), Evidence-only (no `## Change` yet — the
  exact line is unconfirmed, left for whoever picks it up next).
  ~15 extra tool calls (source reads, one repro sequence, the write-up)
  beyond a world where `take`'s live answer is trusted immediately once
  it disagrees with a summary the orchestrator has independent reason
  to distrust — same shape and same order of cost as the prior pass's
  entry on this.
- goal: fill the rest of the wave (N=9) with more disjoint pullable
  builds after `mEBx_YKCA`. Every other band-8 candidate inspected
  (`uS5o_Bw1b`, and the wall `vCsZ_TzIP`) either ends on the same
  cross-org wall or needs the same build-a-binary-and-measure refine
  investment `mEBx_YKCA` took (~90s build + fixture runs). Stopped the
  wave at one build rather than repeat that per candidate: no signal
  this pass has that the next N-1 candidates are any cheaper to refine
  than this one was, and `--routine`'s own terseness weighs against
  opening several more expensive investigations in one unattended
  pass. Left as a real limitation, not a wall — a future pass with
  more width budget should keep working band 8 top-down the same way.

## build mEBx_YKCA (background, build-mEBx_YKCA-07d1f69e) — in flight at pass end
- claimed under the minted label after a stray first `take` (below),
  branch `3IYTD6Mm` off `origin/main`, worktree `/home/user/wt-mEBx_YKCA`.
  Spawned; not yet reported when this pass ends. Per `orchestrate`
  ("never wait inside a pass... still running: leave it"), reconciled
  on the next pass or via the PR-watch this session keeps once the
  agent reports (`take mEBx_YKCA --pr N`, then a review claim).
  goal: claim under the brief's own minted label
  (`build-mEBx_YKCA-07d1f69e`) as `orchestrate` requires ("claim under
  the string its own verdict line names").
  actually happened: called `take mEBx_YKCA` with no `--session` first
  (out of habit from the plain refine/probe calls earlier in this
  pass), which claimed it under this session's bare identity instead
  of the minted label `brief builder` itself names on its verdict
  line. Caught before spawning the agent by reading `brief builder`'s
  own trailing line ("claim it as build-mEBx_YKCA-07d1f69e"); fixed
  with one `take --force` re-claim under the correct label. 1 extra
  tool call, no rework since no agent had been spawned yet.
  contributed: nothing spawns automatically between `take` and `brief`
  in this tool, so a `take` called before reading the brief's minted
  name has no guard against using the wrong session string.
  improvement: read `brief KIND ID`'s own verdict line for the minted
  label BEFORE the first `take` on that item, not after — a one-line
  habit, not a tool or doc gap; not filing as an item, holding here as
  a note for the next orchestrator pass (this session's own).

## candidates
- «Vahb_Krg9» — filed: `show`/`next`'s pullable/recommendation
  computation is stale relative to `take`'s live read immediately
  after a `spec` write clears an item's bar. Second independent
  occurrence (first held, unfiled, in the now-closed `5BNQ_dnD4`);
  this pass had the source access and repro the first one lacked.
