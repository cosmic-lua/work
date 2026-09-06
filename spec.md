# friction: 2026-09-06 work5-routine (/work 5 --routine)

## orchestrator
- goal: open the friction log before the first board verb, per
  `skills/work/friction.md`'s own step order.
  actually happened: ran `sync`, `next` (x5), and 5 `take`s before
  creating this file — the log was opened only once the wave was
  already fully claimed and spawning was underway.
  contributed: nothing in the `/work` bootstrap or the `next`/`take`
  command output itself prompts for the log; it is easy to move
  straight from `sync` into claiming once the board looks tractable.
  improvement: treat "open scratch/friction-<date>-<label>.md" as
  the literal first tool call after `sync`, before even the first
  `next` — put it in muscle memory rather than relying on recalling
  the doctrine mid-pass.

- goal: spawn the first wave agent (Hkal_OAFy) in its prepared worktree
  at `/home/user/worktrees/Hkal_OAFy`.
  actually happened: called `Agent` with `isolation: "worktree"`,
  which creates its own temporary worktree of whatever repo the
  orchestrator's shell cwd was in at call time (`/home/user/cosmopolitan`,
  left over from an earlier `cd`) — ignoring the manually prepared
  cosmic worktree the prompt text pointed at. Caught before the agent
  did meaningful work; killed with `TaskStop` and relaunched without
  `isolation`. Cost: one wasted Agent launch + one TaskStop call, ~2
  tool calls, negligible tokens (agent killed almost immediately).
  contributed: the Agent tool's `isolation: "worktree"` silently
  overrides a hand-prepared worktree path named in the prompt — there
  is no error or warning that the two are in tension, and the tool
  description doesn't flag that isolation ignores prompt-embedded
  paths/branch names, which matters here because the board's own
  `take` already names a specific required branch per item.
  improvement: when the orchestrator has already run `gitboard take`
  and built a worktree on the branch `take` names, never pass
  `isolation` to Agent — a doc sentence in `gitboard help orchestrate`
  ("spawn without Agent's own `isolation` option — the worktree and
  branch are already yours from `take`") would have prevented this
  outright; filed as a candidate below.

- goal: claim item sessions using the `<kind>-<handle>-<orch8>` shape
  `gitboard help orchestrate` documents.
  actually happened: used a shortened handle (`build-Hkal-0bdbc441`,
  `build-XvG7-0bdbc441`, etc.) instead of the item's full handle
  (`build-Hkal_OAFy-0bdbc441`) for all 5 initial claims. This was
  harmless for the 4 build/research claims (self-consistent, no
  contention), but for XvG7_47u0's later review claim it caused a
  refused `take` (`REFUSED: ... is under review by review-XvG7-0bdbc441
  — take over a live review with --force --why`) once I tried to
  re-claim under the brief's exact minted string
  (`review-XvG7_47u0-0bdbc441`), requiring a second `--force` take.
  Cost: 1 extra `take` call plus the refusal round-trip.
  contributed: the convention's exact string
  (`<kind>-<full-handle>-<orch8>`) is fully derivable in advance
  without calling `brief` first, but nothing prompts for the FULL
  handle specifically — it's easy to reach for the shorter form used
  in board display.
  improvement: always compute the claim session as
  `<kind>-<full-handle>-<orch8>` (the handle exactly as `show`/`next`
  print it, e.g. `Hkal_OAFy` not `Hkal`) before the first `take`, not
  after seeing `brief`'s own printed suggestion.

- goal: hand off XvG7_47u0's build with no diff to produce (its own
  spec concluded PR #390 already resolves it).
  actually happened: used `take ID --result` — the mechanism
  `gitboard help review` documents for a *research* item's non-diff
  handover — on a `role: work` item. The tool accepted it without
  complaint and moved the item to `state: review`, but the doctrine
  text only describes this path for research slices, leaving it
  ambiguous whether reusing it for an ordinary build item that turns
  out to need no diff is the intended mechanism or a coincidence of
  the tool not checking role.
  contributed: `gitboard help review`'s wording ("A research item
  takes the same verdicts... Its handover is `take ID --result`")
  reads role-scoped, but nothing in `take --result`'s own `--help`
  text restricts it by role.
  improvement: clarify in `gitboard help review`/`orchestrate` whether
  `--result` is available to any item whose own spec concludes no diff
  is needed, or is meant to be research-role-only (in which case a
  `work`-role item reaching this conclusion should use a different,
  currently undocumented path — e.g. `done --reason completed --force`
  citing the settling PR).

## build Hkal_OAFy (casts: zip.tl reader-cast removal) — blocked, respec'd, bounced
- goal: land the `zip.tl` reader-cast removal once all three staged
  preconditions (binding merged, release descends from it, pin bumped)
  held.
- actually happened: all three preconditions verified true, but a cold
  build (`rm -rf o`, full `--make ci`) still failed —
  `_types/gentype_defs.tl`'s type-generation bootstrap for `zip`
  `require`s `cosmic.zip` itself, so `cosmic/zip.tl` cannot be the
  first consumer of a brand-new `cosmo.zip.*` binding in the same pin
  bump that introduces it (chicken-and-egg: generating the type needs
  compiling the file that needs the type). 63 tool calls, ~25 spent
  isolating the circularity once the first type error looked ordinary.
  Also surfaced a genuine unrelated defect along the way (the same pin
  bump exposes `cosmic/net/init.tl:72`'s unnarrowed `unix.socketpair`
  second return, retyped `integer|string` by an earlier merged PR).
  contributed: nothing in the item spec, `AGENTS.md`, or D43 flags that
  `cosmic/zip.tl` specifically sits inside the type generator's own
  bootstrap closure — a fact only a cold build surfaces, and the item's
  own `## Change` never said "verify on a COLD build," only `--make
  ci` (which reuses whatever `o/` already exists and would not
  necessarily hit this).
  improvement: (1) filed the circularity as its own prerequisite child
  item (`0oBN_Fa6X`) with the fix scoped (make `_types/gentype_defs.tl`
  read `definitions.lua` via raw `cosmo.zip` instead of the
  `cosmic.zip` wrapper) and the already-committed (unpushed) diff on
  branch `3Iw35aAO` named as the resume point; (2) filed the
  `cosmic/net/init.tl` defect separately (`GgVi_79Ne8`); (3) worth a
  standing doc note (not filed as its own item — too small): any item
  whose `## Change` lands a pin bump alongside code consuming a BRAND
  NEW binding from that same pin should say "verify on a cold build,"
  not just `--make ci`, since converged/incremental state can hide
  exactly this class of bootstrap-ordering bug.

## build QNQK_p3Wg (cosmopolitan CAP_* constant lookup) — PR #392, awaiting review
- goal: add `unix.CAP` as a name→value lookup table, mirroring
  `rhKJ_HSQd`'s `unix.E`/`unix.SIG` shape.
- actually happened: clean run, 49 tool calls, ~100k tokens. One
  judgment call flagged in advance by the spec (whether `CAP_LAST_CAP`
  is a genuine capability or an alias) resolved correctly in a single
  header lookup (`libc/sysv/consts/cap.h`: it's `#define CAP_LAST_CAP
  CAP_CHECKPOINT_RESTORE`, excluded — 41 genuine entries, not the naive
  42).
- contributed / improvement: none — this is what a well-scoped,
  precondition-verified brief produces. No friction reported by the
  agent either.
- orchestrator note: forgot to record the PR handover (`take --pr`)
  before trying to claim review — `take --session review-...` refused
  ("claimed by build-... — take over a live claim") until `take --pr
  392` ran first. Minor (1 extra refused call); the fix is procedural,
  not a tool gap: always `take ID --pr N` immediately on hearing a
  builder's PR number, before doing anything else with that item.

## build FePr_L4FB (casts: record-field narrowing tl patch) — PR #1743, CI red, fix dispatched
- goal: land the `narrow-record-field` checker patch, reusing a prior
  attempt's engineering already committed on the item's own branch.
- actually happened: builder found the prior attempt (commit
  `f0234765`) complete and correct, did the one remaining step (D21
  amendment unblocked filing without an upstream issue), got a clean
  local `bin/cosmic --make ci` PASS (5 stages, 3273/3273), pushed,
  opened PR #1743 — but GitHub CI's `ci` job failed with 2 test
  failures the local run did not catch: `_build/gotchas_test.tl`'s
  `test_every_symptom_is_real_and_gated` and
  `cosmic/_teal_hints_test.tl`'s
  `test_previously_shadowed_sections_now_name_themselves`, both because
  a THIRD place in the tree (`_build/testdata/gotchas/record-fields-
  dont-narrow.tl`, a fixture that exists specifically to document this
  exact "record field doesn't narrow" gotcha as a REAL, currently-
  refused-by-the-checker symptom) now type-checks clean under the PR's
  own patch, so the ratchet tests asserting it's still broken fail.
  contributed: the builder's own friction entries name the likely
  cause — a mutate→rebuild→restore→rebuild cycle during mutation
  testing can leave `o/`'s incremental graph inconsistent with the
  restored source, so a "PASS" run right after restoring may not have
  actually rebuilt everything CI rebuilds from a truly clean checkout.
  Separately: the gotchas fixture set is a THIRD encoding of "this
  pattern is broken" (alongside the canary in `cosmic/teal_test.tl`,
  already flipped, and the `narrow_record_field.tl` patch entries
  themselves) that the item's own spec never mentioned — a spec author
  writing "flip the canary" named only one of at least two ratchets
  this exact fix needed to flip.
  improvement: dispatched a scoped fix agent (in the SAME worktree/
  branch, new commit) to retire or convert the now-stale gotchas
  fixture per the repo's own established convention for a closed
  gotcha, then re-verify with a genuinely clean (`rm -rf o`) `--make
  ci` before pushing. Worth a doc note once confirmed: a checker-
  behavior-changing patch should grep `_build/testdata/gotchas/` for
  fixtures matching the pattern it fixes, not just the one canary test
  file its own evidence happened to cite.
- fix agent's own finding, larger than expected: the real root cause
  wasn't just the gotchas fixture — the item's branch had been cut
  before the whole gotchas-ratchet system landed on `main` and was 59
  commits behind, so GitHub's PR-merge-ref CI saw the conflict while a
  local build against the stale branch tip did not. Fixed by merging
  `main` in first (clean, no textual conflicts), retargeting the
  now-obsolete gotcha fixture to the genuine residual case (a guard two
  field-accesses deep, `o.mid.inner`, rather than one field off a plain
  variable) following the PR's own established canary-flip precedent,
  and splitting an unrelated file that crossed the 500-line cap as a
  side effect of the merge. `rm -rf o` clean `--make ci`: PASS
  (3341/3341, 289/289). Pushed `93017d90`; CI re-running on the new
  head as of this entry.
  contributed: two tool-shape gotchas the fix agent hit and named:
  (1) the worktree was a shallow clone, so `merge-base`/`rev-list`
  ancestry math gave nonsense numbers until `git fetch --unshallow`;
  (2) `git restore --staged --worktree` mid-merge with no explicit
  source defaults to pre-merge `HEAD`, silently discarding the merge's
  own changes when used to isolate a hand edit — a stash or diff-and-
  reapply is the safe move instead.
  improvement: (1) is worth a standing note for any worktree-based
  fix/rebase task — `git fetch --unshallow` before trusting ancestry
  math on a worktree checked out from this session's own git setup;
  (2) is a one-line git-usage caution, not a tool or doc gap in this
  repo specifically.
- review of the post-fix head (93017d90): accept, 45 tool calls,
  ~123k tokens. Independently reproduced the mutation-test failure
  from a cold rebuild, confirmed all 5 named cast sites byte-identical
  to main, confirmed the gotchas-fixture retarget and file-split were
  genuinely forced by the stale-branch merge (not scope creep, verified
  via line-count history across the merge), confirmed D21's amendment
  is real. Auto-merge (squash) enabled, queued.
  contributed / improvement: none — clean accept.

## research HlZW_zWbs (semantic rename for Teal spike) — request-changes, corrected, re-reviewing
- goal: settle whether `tl`'s existing APIs can back semantic rename.
- actually happened: clean, thorough research (35 tool calls, ~105k
  tokens) with two decisive, reproduced empirical tests (value-
  collision on `symbols_in_scope`'s returned slot, both a same-decl and
  a shadowing case) — both held up under the adversarial re-review.
  One inline parenthetical claim ("`identifier` is... used e.g. for
  labels") was NOT tested, just inferred, and the review disproved it
  directly (a label parses to a `"label"`-kind node with no identifier
  child at all; the only `identifier`-kind node in the reviewer's
  fixture was a `fornum` loop variable). request-changes for that one
  line; everything else — the recommendation, the line citations, the
  non-goals — held.
  contributed: exactly the failure mode the spec's own evidence
  standard exists to catch — an unverified aside sitting right next to
  two rigorously verified claims, in prose easy to skim past as
  "obviously also checked."
  improvement: applied the reviewer's own correction verbatim (tested
  directly, cites the real mechanism — label name lives in a `.label`
  string field, not a child node), re-handed-over, re-review spawned.
  No process gap to fix beyond what the review process already caught
  by design — this is the review doing its job.
- second review (re-review of the correction): accept, 50 tool calls,
  ~97k tokens. Independently re-parsed the label/fornum fixture and
  confirmed the correction's claim exactly. Two agent-reported friction
  items worth carrying forward: (1) the spec's own `symbols_in_scope`
  probe snippet is missing `tl.process_string`'s real 4-arg signature
  (`input, is_lua, env, filename`) — cost the reviewer ~3 calls to
  diagnose from a runtime error; (2) `require("tl")` under `o/bin/cosmic`
  resolves to the BINARY's embedded `/zip/tl.lua`, not the tree's
  `o/3p/tl/tl.lua`, even with `package.path` prepended — undocumented,
  worth a line in AGENTS.md or `guide.gotchas` since any tl-probing
  research item will hit this.
- item done: `gitboard done HlZW_zWbs --reason completed` → completed
  (accepted).

## review XvG7_47u0 (fetchstream floor verification handover) — completed, accept
- goal (builder, first pass): confirm `#390` merged and the coverage
  floor comment accounts for `test_stream_https`'s network variance.
  actually happened: single `grep` against the merged
  `line_coverage_floor.lua` comment confirmed it in one tool call, 2
  tool calls total, ~48k tokens, 17s wall. No rework, no ambiguity.
  contributed: the spec's own Change section named the exact file,
  the exact expected phrasing, and the fallback ("if not confirmed,
  STOP") — nothing left to infer.
  improvement: none needed — this is the shape every builder brief
  should aim for.
- (reviewer's own friction reported once it completes, appended here)

## refine 3IQtgMjy (census container reconciliation) — orchestrator-authored, review spawned
- goal: close out the census container once `gitboard done` on an
  unrelated item (`XvG7_47u0`) reported it as its grandparent's "last
  open child," per the container's own `## Change` ("re-run
  census.awk... verify union... record the reconciliation... then end
  the item").
- actually happened: did the reconciliation directly (not delegated) —
  re-ran `census.awk` against current `origin/master`, cross-referenced
  all 187 currently-NIL bindings against the twelve children's own
  tables (three separate regex passes needed: two-level dotted names,
  colon-method names, and short/module-prefix-dropped names each
  needed different matching, ~10 tool calls before the comparison was
  trustworthy). Found one apparent gap (`zip.reader`) that resolved to
  "new binding added after the walk, correctly out of scope," and
  wrote the reconciliation into the item's spec.
  contributed: `gitboard done` on a no-diff item REFUSED without a
  recorded verdict ("an evidence-only item takes a verdict too") —
  same `take --result` → claim review → `verdict` → `done` cycle as a
  research handover, even though this item's role is `work`, not
  `research`; cost one refused `done` call and a bit of confusion.
  Because the orchestrator did this analysis itself rather than a
  distanced subagent, the normal builder/reviewer distance the review
  doctrine relies on didn't exist here by construction — worth flagging
  explicitly to whatever reviews it, which the spawned review brief
  does (told to treat the Result section with extra skepticism for
  exactly this reason).
  improvement: for any container/no-diff item an orchestrator verifies
  directly (not via a spawned agent), explicitly flag that fact in the
  review brief so the reviewer knows to apply extra scrutiny rather
  than the normal "trust the claimant's transcript, verify
  independently" default. Already done here; worth folding into
  `gitboard help orchestrate`'s own text as a standing instruction
  rather than something each orchestrator has to think to add.
- second review (after the missed-binding fix): accept, 37 tool calls,
  ~111k tokens. Independently redid the FULL 187-binding cross-
  reference from scratch (not sampled) and found exactly the same two
  exceptions the fix added — no third miss. Verified both bindings'
  provenance directly against the GitHub API rather than trusting the
  spec's pasted git commands. `done` recorded: completed (accepted),
  no cascade to its own parent (other siblings still open).
  contributed / improvement: none new — the fix held under a genuinely
  independent, complete re-check, which is what a "your first pass
  stopped early" request-changes is supposed to produce.

## review QNQK_p3Wg PR #392 — accepted, auto-merge enabled
- goal: adversarial review of a straightforward, well-scoped diff.
- actually happened: clean accept, 42 tool calls, ~92k tokens.
  Independently rebuilt from a cold cosmocc download, diffed the
  41-entry table against the 42 raw field calls, verified the
  `CAP_LAST_CAP` exclusion against the libc header directly, and
  reproduced the mutation-test failure. No findings.
  contributed / improvement: none on the substance. One minor doc gap
  the reviewer flagged: `make -j4 o/tool/lua/test_definitions_conformance.ok`
  doesn't actually re-run the test standalone (loops on `o//depend`
  regeneration instead) — invoking the built `lua.dbg` directly on the
  `.lua` file is the fast, correct way to re-run one test file after
  the toolchain exists; worth a line in AGENTS.md.
- merged: PR #392 landed via the merge queue at 07:34:47Z.
  `gitboard done QNQK_p3Wg --reason completed` → completed (accepted).
  Filed its own downstream follow-up (`SvoZ_eTH`, closing
  `cosmic/quicksand/caps.tl:63`'s cast once a cosmos release carries
  `unix.CAP` and the pin bumps) while waiting on the merge queue.

## roll call (exact claim-session headings, per agent actually spawned)

The sections above give the full account of each agent's work; this
section exists only to name every claim session this pass minted, in
the tool's own `## <kind> <handle>` shape, including the two
short-handle claims made before the full-handle convention correction
mid-pass (see the orchestrator's own second entry above).

## build Hkal
Session `build-Hkal-0bdbc441`. Full account: "build Hkal_OAFy" above.

## build XvG7
Session `build-XvG7-0bdbc441`. Full account: "build XvG7_47u0
(fetchstream floor verification handover)" above (the item's builder
report; the item's own board id is XvG7_47u0).

## build QNQK
Session `build-QNQK-0bdbc441`. Full account: "build QNQK_p3Wg" above.

## build FePr
Session `build-FePr-0bdbc441`. Full account: "build FePr_L4FB" above.

## research HlZW
Session `research-HlZW-0bdbc441`. Full account: "research HlZW_zWbs"
above.

## review XvG7
Session `review-XvG7-0bdbc441` — the first review claim on XvG7_47u0,
superseded within the same pass by `review-XvG7_47u0-0bdbc441` (the
brief's own minted string) via a `--force` re-take once the mismatch
was caught. No agent work lost — this was an orchestrator claim-label
correction before any review agent was spawned under the wrong label.
See the orchestrator's second entry above.

## review HlZW_zWbs
Session `review-HlZW_zWbs-0bdbc441`, used for both the first review
(request-changes on the `"identifier"`-for-labels claim) and the
second (accept, after the correction). Full account: "research
HlZW_zWbs" above, which covers both review rounds inline.

## refine qwOH_fdJl
Session `refine-qwOH_fdJl-0bdbc441` — the orchestrator's own
reconciliation work on the census container (item handle `qwOH_fdJl`,
board id `3IQtgMjy...`). Full account: "refine 3IQtgMjy" above.

## review qwOH_fdJl
Session `review-qwOH_fdJl-0bdbc441`, used for both review rounds on
the census reconciliation (request-changes for the missed
`register_extension` binding, then accept). Full account: "refine
3IQtgMjy" above, which covers both review rounds inline.

## review FePr_L4FB
Session `review-FePr_L4FB-0bdbc441`. Full account: "build FePr_L4FB"
above, which covers the review outcome inline (accept, auto-merge
enabled, later merged).

## candidates
- "spawn without Agent's own `isolation` option once `gitboard take`
  has already named a worktree/branch" — stays here for triage: needs
  a `gitboard help orchestrate` wording change, not a code gate; too
  small to be its own outcome.
- "compute claim sessions as `<kind>-<full-handle>-<orch8>` up front"
  — stays here for triage: a self-correcting habit, not a gate or doc
  gap on the tool side.
- "clarify `take --result`'s role scope in `gitboard help
  review`/`orchestrate`" — stays here for triage: confirmed to recur
  (used on both a `research`-role item and a `work`-role container
  this same pass, both accepted by the tool without complaint), but
  the fix is a wording clarification a maintainer can make directly,
  not a build task worth its own item.
- "flag orchestrator-authored (not agent-delegated) reconciliation work
  explicitly in its own review brief, as extra-skepticism instructions"
  — stays here for triage: done ad hoc this pass (3IQtgMjy's review
  brief); worth folding into `gitboard help orchestrate`'s standing
  text, but a wording addition, not a build task.
- "a spec landing a pin bump alongside code consuming a BRAND NEW
  binding from that same pin should require a COLD build, not just
  `--make ci`, to catch bootstrap-ordering circularities" — stays here
  for triage: surfaced by `Hkal_OAFy`'s bounce, but it's a wording
  addition to whatever refiner-facing guidance covers pin-bump items,
  not a new gate; `Hkal_OAFy`'s own filed prerequisite child
  (`0oBN_Fa6X`) already carries the concrete instance.
- "`require('tl')` under a built cosmic binary resolves to the
  embedded `/zip/tl.lua`, not `o/3p/tl/tl.lua`, even with
  `package.path` prepended" — investigated, turned out to be a
  DUPLICATE of an already-completed item (`RoQH_GT03`, PR #1479, which
  found and fixed this exact hazard — `require` of any embedded module
  ignores `package.path`, `dofile`/`package.loaded` preload is the
  correct probe — and shipped the `_make/patch.tl` `patch.reverse`
  tooling plus the AGENTS.md note). Filed as `3IwfjJOw`, then ended
  `not-planned` (duplicate) the same pass once the existing item
  surfaced. Two independent research sessions still hit this the same
  day, which suggests the existing fix/doc isn't surfacing where a
  `tl`-probing session would see it before hitting the wall — worth a
  discoverability look (e.g. does `guide.checking`/`guide.gotchas`
  actually mention it), but that's a documentation-placement question
  for a human, not sized here.
- "grep `_build/testdata/gotchas/` for fixtures matching the pattern a
  checker-behavior-changing patch fixes, not just the one canary test
  its own evidence cites" — filed as «WK7pGljy» (checked against the
  board's own similar-title suggestions at file time; none was a
  duplicate — closest was `DypT_hD7b`, about hint-message wording, a
  different concern). Sized as its own tiny item (a checklist line for
  `docs/decisions/d21-carried-tl-patch.md` or CLAUDE.md).
