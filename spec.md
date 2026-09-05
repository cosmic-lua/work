# friction: 2026-09-05 work9 (/work 9 --routine)

## pass summary

Reconciled 1 in-flight research item, drove it through 3 rework/review
rounds to accept+done. Refined 2 todo items that missed the spec bar
into buildable specs, both built, reviewed, merged, and closed
(PR #1724, PR #1725). 1 redundant item closed as housekeeping
(not-planned). 1 new countermeasure item filed and placed.

## orchestrator

- **goal**: reconcile a research item («CCB2_BBra») already sitting in
  `doing [review]` when this pass started, so the wave could open with
  `sync` per orchestrate doctrine.
  **actually happened**: `take ID --session review-<handle>-<orch8>`
  worked as expected the first time. Clean, no retries.

- **goal**: after the review returned `request-changes`, resume the item
  as its next rework round — spawn a fresh research agent to redo the
  fixture and hand the corrected spec back over via `take ID --result`.
  **actually happened**: called plain `take ID --session
  research-CCB2_BBra-3c1cde43` (no `--pr`/`--result`) expecting it to
  transfer the "claim" field to my new session, matching the string
  `gitboard brief research ID` itself told me to claim under. Instead it
  silently recorded me into a SECOND field, "reviewer" (`gitboard-take:
  3ItPDqwH's review is yours`), leaving "claim" unchanged at the
  original `research-CCB2_BBra-5c8fc82c` (a prior orchestrator pass's
  session, now long gone). Retried with `--force --why ...`: got
  `gitboard-take: 3ItPDqwH's review is already yours` — same no-op.
  Cost: ~4 extra tool calls (two `take` attempts, a `show` to notice the
  discrepancy, a `git for-each-ref`/`git log` dig through the item's own
  ref history) before reading the actual commit log on the item's ref
  (`git log refs/heads/items/<id>`) and discovering the real pattern: a
  "doing" item's original "claim" persists across an ENTIRE rework
  cycle (spec update → `take --result` → review → request-changes →
  spec update → `take --result` → ...) and is never re-taken; only the
  session that ALREADY holds "claim" may call `spec` (open to anyone)
  and `take --result` (restricted to the claim holder, enforced by
  matching `--session` string, not by anything live). A brand-new
  orchestrator pass continuing someone else's still-open rework round
  has no verb to formally "adopt" the claim — it just has to reuse the
  literal historical session string for the handover call, which
  `gitboard brief research ID`'s own footer text ("claim it as
  research-CCB2_BBra-3c1cde43") does not warn about, because that text
  is generic first-claim boilerplate reused verbatim for a rework brief
  too.
  **contributed**: `gitboard help system`'s doctrine describes the two
  states (todo/doing) and the two doing exits (block-first vs. drop) but
  never states that "doing"'s underlying claim is immutable once set and
  outlives the orchestrator session that set it, nor that a plain `take`
  on a non-todo, non-fresh-review item degrades to a second, mostly
  inert "reviewer" annotation instead of erroring. `gitboard brief
  research ID`'s footer ("claim it as research-CCB2_BBra-3c1cde43")
  is copy-pasted for both the fresh-pull and the rework case and is
  actively wrong for the latter.
  **improvement** (gate in the tool, ranked over a doc): `take` should
  refuse outright (not silently write a "reviewer" field) when called
  without `--pr`/`--result` on an item whose state is neither `todo` nor
  freshly `review`-eligible, naming the actual claim holder and telling
  the caller to reuse that session string for `spec`/`take --result`
  instead. Failing that, `gitboard help system`'s doing-state paragraph
  should say explicitly that the original claim string is immutable
  across a rework cycle and must be reused by string, and `brief
  research ID`'s footer text should vary between "claim it as X" (fresh
  pull) and "the existing claim holder is X — reuse that string for your
  `spec`/`take --result` calls" (rework). Candidate below.

- **goal**: after the refine agent updated «cVOC_iLy7»'s spec so it
  passed the bar, find the next actionable item via `next`.
  **actually happened**: `next` kept recommending `refine «cVOC_iLy7»
  ... the highest-placed todo item that misses the spec bar` for two
  consecutive calls (with a `sync` in between reporting "state is
  current") AFTER `show cVOC_iLy7` already showed no `bar:` warning and
  the item's own git ref (`refs/heads/items/3IpXczpG...`) carried the
  new `spec` commit. Took the risk of calling `take cVOC_iLy7
  --session build-...` directly against `next`'s advice — it succeeded
  immediately (`3IpXczpG is yours — branch 3IpXczpG off main`). A
  `next` call afterward correctly advanced to the next item, so the
  staleness was transient, not a wrong read of the merged board.
  **contributed**: the pinned gitboard release running this session
  (`2026-09-05-56acf8e`) is built from a commit literally titled
  "cache: derive an events table from each item's commit chain (#38)"
  — consistent with `next`'s priority/bar view being served from a
  cache that a plain `sync` does not force to rebuild immediately after
  a sibling `spec` write lands.
  **improvement**: not yet root-caused (would need the tool's own
  source, out of scope for an orchestrator session) — flagging as a
  candidate for whoever owns gitboard's cache invalidation: `sync`
  should either block until the events cache reflects the ref it just
  fetched, or `next`'s output should say plainly when it is serving a
  cached read that may lag a `spec`/`take` written moments earlier, so
  an orchestrator does not have to learn to distrust `next` empirically
  under time pressure.

- **goal**: after claiming `nG3p_QYHj` for review once CI went green,
  spawn the fresh reviewer agent for PR #1725.
  **actually happened**: got distracted by the CCB2_BBra research-rework
  completion notification arriving in the same turn, applied its spec
  and moved straight into spawning that item's round-2 review — the
  `take --session review-nG3p_QYHj-...` call succeeded but no Agent
  call followed it. The gap sat unnoticed for roughly two full
  round-trips (the CCB2_BBra round-2 AND round-3 review cycles) before
  a `show nG3p_QYHj` check (prompted by nothing more than re-verifying
  state before writing this log) caught it: `state: review`, `reviewer:
  review-nG3p_QYHj-3c1cde43` claimed, but no agent ever ran.
  **contributed**: no tool refusal or error — the claim succeeded fine,
  so nothing signaled the missing step; two competing PR review threads
  arriving close together in-context made it easy for one silent no-op
  to hide behind the other's real activity.
  **improvement**: after every `take --session review-...` call, the
  very next action should be the `Agent` spawn call in the same
  reasoning turn, never deferred past an interleaved event — a
  checklist habit, not a tool fix. Worth a `gitboard help orchestrate`
  callout: "claim and spawn are one atomic step from the operator's
  side; the tool cannot enforce that they stay paired."

- **goal**: `gitboard done CCB2_BBra` immediately after round 3's
  verdict landed.
  **actually happened**: refused once ("has no PR and no accept")
  because the local board checkout hadn't yet synced the review
  agent's just-recorded verdict commit; a `sync` immediately before
  retry resolved it cleanly.
  **contributed**: not a real defect — a `done` call right after a
  background agent's own board write should always `sync` first.
  **improvement**: none needed, just re-run the pass's own `sync`
  habit after every agent-notification, not only at pass boundaries.

## review CCB2_BBra (general-purpose, background × 3 rounds) — request-changes, request-changes, accept

Round 1: 466s wall, 30 tool calls, 30 Bash. in=62 out=114
cache_read=2211898 cache_create=112148; no errors; repeated commands:
`SCRATCH=...` ×20, `cd /home/user/work` ×6.

- **goal** (from its own report): independently verify the bm25/Jaccard
  numbers the spec's Result section pasted.
  **actually happened**: found no runnable script or query path anywhere
  in the spec for the bulk of the measured numbers (only the Evidence
  section's early prototype pasted a runnable snippet) — spent effort
  instead manually re-reading five source files' doc comments
  (`url.tl`, `user.tl`, `fs/path.tl`, `string.tl`, `fs/dir.tl`) to
  sanity-check the fixture's TRUE/CONTROL labels by hand. This detour is
  exactly how it found the real defect (an inconsistent labeling rule
  for templated doc comments), so it was productive, but the agent
  itself flagged it as "only possible because I happened to spot-check
  exactly the right pairs" — a near-miss.
  **contributed**: the spec's bar ("measured, not inferred... command
  AND pasted output") was applied to the readiness probe and the
  extractor's aggregate counts, but not to the per-block bm25/Jaccard
  scoring itself — no extractor/scorer script location was named for a
  reviewer to rerun.
  **improvement**: a research item whose Result carries per-block
  numeric tables should name where the scoring script lives (even as a
  board-item attachment, since it never touches the product tree) so a
  reviewer reruns the exact query instead of auditing by hand. Doc/skill
  level — `skills/work/decompose.md` or `gitboard help bar`'s "measured,
  not inferred" paragraph could say this explicitly for research items.
- **goal**: locate a capture the spec cited as `cY1cArl`.
  **actually happened**: `gitboard show cY1cArl` returned no match; a
  `git grep` over `refs/heads/items refs/heads/ended` (~2 extra calls)
  found the real handle was `qcY1_cArl` — the spec had dropped the
  leading `q` when transcribing the id.
  **contributed**: a hand-transcribed handle citation, not copied
  verbatim from a `show`/`new` verdict line.
  **improvement**: a spec-writing convention (refine and research briefs
  both) to paste a cited handle from its own bracketed `«handle»` render
  rather than retype it. Cheap, doc-level.

Round 2: 484984ms wall, 45 tool calls.

- found `_make/policy_test.tl:124` mislabeled CONTROL (a 3rd member of
  an already-TRUE duplicate cluster) by adversarially spot-checking 18
  rows the round-1 reviewer had NOT flagged, per the brief's explicit
  instruction to do so — exactly the check design intended, and it
  paid off a second time.
  **goal**: reproduce the spec's bm25/Jaccard numbers independently.
  **actually happened**: infeasible — no extractor/scoring script was
  ever committed (a research item recommending "no follow-up" ships no
  code by design); built a 6-row toy FTS5 index to sanity-check the
  technique, then recognized bm25/IDF is corpus-size-dependent so a
  6-row toy corpus's absolute ratios don't transfer to the real
  6229-block corpus's conclusions — fell back to reading source
  directly and applying the stated rule by hand, after ~4 tool calls
  building and discarding the toy script.
  **contributed**: same root cause flagged in round 1's own friction,
  recurring.
  **improvement**: unchanged from round 1's candidate.
- **goal**: trust the session scratchpad as empty at task start.
  **actually happened**: found leftover files from what looked like a
  prior session's work already in the scratch directory
  (`corrected_spec.md`, `fixture.txt`, `index_prose.tl`,
  `score_fixture.tl`, a non-git `work/` dir) — moved them aside and
  re-cloned fresh rather than trust them, one extra round-trip.
  **contributed**: the scratchpad directory is session-scoped but not
  always empty when multiple agents/passes reuse the same session's
  scratch path.
  **improvement**: minor — worth a one-line brief reminder to check for
  and move aside pre-existing scratch content rather than assume a
  clean directory.

Round 3: 250860ms wall, 36 tool calls.

- verified the central round-3 claim, re-derived both signals' margins
  by hand-scanning all 60 rows (not trusted from the spec text), and
  confirmed the reclassified row was never the extreme value on either
  signal. One friction item: `gitboard show` rejected the `«CCB2_BBra»`
  bracket-and-guillemet handle form despite docs claiming any divider
  works; bare handle and full ID both worked immediately.

## research CCB2_BBra (general-purpose, background — round 2 rework; round 3 was orchestrator-applied directly)

Round 2 rework: 1402149ms wall, 58 tool calls.

- **goal**: get `--make run` to compile a scratch `.tl` script outside
  the tree.
  **actually happened**: failed immediately (`no such source`) — one
  wasted tool call before moving the script inside the tree root.
  **contributed**: `--make run` resolves sources against the project
  root; not stated in AGENTS.md.
  **improvement**: one-line note in the build-system section of
  AGENTS.md ("`--make run <path>` requires `<path>` under the project
  root"). Doc-level, cheap, recurring across sessions that try a
  scratch script.
- **goal**: compute Signal B (Jaccard) "best other" via an FTS5 MATCH
  OR-query.
  **actually happened**: first version silently returned near-random
  low scores (~0.15-0.3) for every entry including known near-exact
  duplicates; ~15 minutes and 3 debug queries to find the cause —
  `LIMIT 200` with no `ORDER BY bm25(blocks)` returns SQLite's
  unordered match order, filling the limit window with arbitrary
  documents instead of the closest ones.
  **contributed**: no doc or spec text warns that an FTS5 MATCH needs
  explicit rank ordering before LIMIT narrows it usefully.
  **improvement**: recorded as an implementation note in the corrected
  spec itself for the next person — good outcome, the fix is already
  captured where it's needed.
- **goal**: locate fixture blocks by the line numbers the round-1 spec
  cited.
  **actually happened**: found the labels (not the line numbers) had
  drifted independent of the reviewer's complaint — `url.tl`'s 5
  `safe_*` parenthetical names were shifted by one function, and
  `codec.tl:102` was mislabeled `encode_base64url` instead of
  `decode_base64url`. Fixed while rebuilding the table.
  **contributed**: a copy/paste-while-renumbering slip in the original
  research pass; scores were keyed correctly to the line, only the
  human-readable label drifted.
  **improvement**: none needed beyond the fix already made.
- **goal**: decide how strictly to apply the reviewer's plural phrase
  ("rusage.tl's getter/setter pairs") when only one of the file's two
  pairs actually passes the stated TRUE/CONTROL rule.
  **actually happened**: resolved by calibrating the rule against
  round 1's own already-accepted TRUE pair rather than pattern-matching
  the reviewer's prose, and flagged the interpretive gap explicitly
  rather than silently picking one reading.
  **contributed**: the review's phrasing generalized from two clean
  examples to a claim about all five named items without checking each
  one — not a spec/tool defect, a review-writing habit worth naming if
  it recurs.
  **improvement**: none needed — flagged, not silently resolved.
- orchestrator note: the agent's completion notification arrived with
  only 3 of 4 requested report sections — the primary deliverable (a
  ~25 KB corrected spec text) was missing. A SendMessage follow-up to
  the same agent recovered it from a scratchpad file it had written
  earlier.
  **goal**: receive a spawned agent's full deliverable via its
  completion notification.
  **actually happened**: the notification's result text cut off before
  item 1 (the recommended full new spec); recovered only by an extra
  round-trip message asking the agent to re-paste it from its own
  scratch file.
  **contributed**: unclear from this session alone — possibly a
  length/formatting limit somewhere in the notification pipeline for a
  very large text block inside a final report.
  **improvement**: for a research/refine brief whose deliverable is a
  large spec text, instruct the agent to ALSO write it to a scratch
  file path and name that path in its final report — worth adding to
  `gitboard brief research`/`refine`'s own template. Candidate below.
- housekeeping note (orchestrator, not this agent): while reconciling
  this item's captures, found «LOP1_MhAs» (filed by round 1) asks a
  question already answered by its sibling «iltX_EM90»'s own spec
  (filed ~85 min earlier, same disposal). Ended LOP1_MhAs as
  `not-planned` — a housekeeping action, not a finding against this
  item's own research.

Round 3 (orchestrator-applied directly, no agent spawned): moved one
row (`_make/policy_test.tl:124`) from CONTROL to TRUE per round 2
review's own concrete, already-verified finding; margins unaffected on
both signals per the reviewer's own confirmation. No new friction — a
small mechanical edit made directly rather than re-running a full
research agent for a change whose numbers were already known.

## build cVOC_iLy7 (general-purpose, background × 2: refine, build)

Refine: 638s wall, 61 tool calls (49 Bash, 1 Edit, 1 Grep, 6 Read,
4 Write), first edit at call 39. in=124 out=8126 cache_read=6201993
cache_create=127261; 3 errors (2 expected compiler-refusal probes, 1
`SSL_USE_SYSTEM_CERTS` retry); repeated commands: `cd /home/user/cosmic`
×36, `export SSL_USE_SYSTEM_CERTS=1` ×8.

- **goal** (from its own report): determine the correct replacement
  cast-sites.tsv class for `fetch/init.tl:388` (`map view of a declared
  value` vs. `incremental record construction`).
  **actually happened**: ~15 tool calls reading `casts.md`'s class
  definitions, the commit that touched the site, and `cast_sites.tl`'s
  reconcile logic, because no class definition literally names "an
  any-typed value arriving whole through a seam, cast straight to a
  concrete record" as its discriminator — resolved by inferring the
  discriminator (cast target: map vs. concrete record) from the classes'
  own examples.
  **contributed**: `casts.md`'s class headings define each class by a
  worked example, not by a stated discriminating rule, so classifying a
  NEW site means reverse-engineering the rule each time.
  **improvement**: `casts.md` doc-level — each class heading could state
  its discriminator as one sentence, once, so both a refiner reclassifying
  a stale row and a builder classifying a brand-new cast can pattern-match
  instead of re-deriving it. Not filed standalone — noted for a
  docs-sweep item to pick up.
- 36× identical `cd /home/user/cosmic`: each Bash call in this
  environment does not appear to persist a working directory across
  calls the way a persistent shell would, so a background subagent
  re-issuing `cd` before nearly every command is either environment
  reality or an agent habit costing ~36 redundant tokens' worth of
  calls. Worth checking against the harness's actual cwd-persistence
  guarantee.

Build: PR #1724 opened, CI green pre-push, 415844ms wall, 54 tool calls.

- **goal** (from its own report): write the two `casts.md` prose paragraphs
  the spec described.
  **actually happened**: `bin/cosmic --make ci`'s lint stage failed twice
  on the same edit for two different reasons — `_build/doc_paths_test.tl`
  flagged a bare `fetch/extras.tl` citation (missing the `cosmic/` prefix)
  as a stale path, then a doc-citation lint rule flagged inline
  `path:line`-style citations (`cosmic/fetch/init.tl:388`, `merge.tl:135`,
  `merge.tl:138`) outside fenced code blocks. Cost ~4 extra tool calls and
  two edit/re-run cycles (~2 min).
  **contributed**: the spec's own worked prose (Evidence/Change sections)
  uses exactly this bare inline-citation style, which reads as the natural
  way to write it — but two independent lint gates (not named in the spec
  or in CLAUDE.md) forbid both patterns in `docs/design/*.md` prose.
  **improvement**: since the item's own reference spec used the pattern
  the gate rejects, a docs-writing convention note (`docs-style` skill, or
  `casts.md`'s own header) naming these two lint rules explicitly would
  save every future builder writing prose in this file the same two-cycle
  discovery. Not filed standalone — noted for the docs-sweep/friction
  triage item below.

## review cVOC_iLy7 (general-purpose, background) — accept, auto-merge enabled, 199443ms wall, 38 tool calls

- no friction reported: spec was precise (exact line numbers, row
  counts, prose deltas), every claim independently checkable in 1-2
  commands, nothing in gitboard/worktree/GitHub tooling misled or
  required rediscovery. Mutation test (corrupted a tsv class heading,
  confirmed the heading-check test failed, restored, confirmed 3/3
  pass again) ran clean on the first try.

## build nG3p_QYHj (general-purpose, background × 2: refine, build)

Refine: spec now passes bar, 2 captures filed, 533510ms wall, 72 tool
calls.

- **goal** (from its own report): confirm a scratch verification patch
  left no residue in the tree before reporting the zero-return diagnosis
  as clean.
  **actually happened**: reverting `3p/tl/tl_patch/narrow.tl` via `cp`
  (not the Edit tool) triggered a harness reminder that the file
  "changed on disk since you last read it," costing one extra
  diff+`git status` round trip to confirm it was its own clean revert.
  **contributed**: using Bash `cp` for a revert doesn't register as an
  intentional edit to the harness's file-tracking.
  **improvement**: use Edit/Write (not `cp`/`sed -i`) to restore from a
  backup during self-verification, at the cost of one extra Read call —
  cheaper than the harness's ambiguous-change reminder. Doc-level
  reminder for brief-writing, not board-worthy alone.
- **goal**: verify a scratch-patched build left no artifact residue.
  **actually happened**: reverting the source patch file alone was
  insufficient — the fetched/unpacked `o/3p/tl/tl.lua` still carried the
  scratch edit (invisible to `git status` since `o/` is gitignored);
  needed `rm -rf o/3p/tl` + refetch + rebuild (3 extra commands, ~1 min).
  **contributed**: AGENTS.md documents `fetch`'s patch-repair as an
  additive/idempotent check, not a full re-sync, so removing a patch
  entry from source doesn't un-apply it from the already-unpacked
  product automatically.
  **improvement**: fed directly into the countermeasure filed below —
  the same trap recurred on the review side too.
- filed 2 capture items decomposing the unrelated sites:
  `Xwrh_16CG` (sqlite/extras.tl pcall-failure-arm mistyping) and
  `Tjmj_tQcb` (_teal_engine.tl TlResult/tl.Result nominal duplication),
  both under the same parent, both Evidence+Question only (no Change
  yet) since neither's fix direction is determined.

Build: PR #1725 opened, local CI green x2 (before/after mutation test),
405201ms wall, 45 tool calls.

- **goal**: fit the new canary test into `cosmic/teal_test.tl` under the
  500-line file cap.
  **actually happened**: first draft (matching the generous comment
  style of the existing `test_narrowing_canary`) landed at 505 lines;
  one extra edit/re-run cycle (~3 tool calls) to tighten it to exactly
  500.
  **improvement**: none needed — the brief already told the agent to
  check the line count first; this is normal iteration, not a gap.
- **goal**: follow "the same sorted-name-ordering convention" when
  inserting the new patch entry into `3p/tl/tl_patch/narrow.tl`.
  **actually happened**: found one pre-existing out-of-order pair
  (`narrow-pack-n` before `narrow-nil-union`) elsewhere in the file,
  momentarily ambiguous against "sorted" — resolved by inserting at the
  position true alphabetical order dictates among the new entry's own
  correctly-ordered neighbors, ignoring the pre-existing anomaly.
  **improvement**: cosmetic, low priority; not board-worthy alone.

## review nG3p_QYHj (general-purpose, background) — accept, auto-merge enabled, 309579ms wall, 36 tool calls

- **goal**: confirm the diff is exactly the spec's stated Change (2
  files) — "the diff is the Change" check.
  **actually happened**: `git diff main...pr-1725` on a pre-existing
  checkout showed 46 unrelated files, because the checkout's local
  `main` ref was several commits stale against `origin/main` — a
  moment of alarm and ~2 tool calls before fetching `origin/main` fresh
  and recomputing against the true merge-base, which then matched the
  PR API's `changed_files: 2` exactly.
  **contributed**: nothing in the review brief warns that a pre-seeded
  checkout's local `main` branch can be stale; the natural first diff
  command uses whatever local ref exists.
  **improvement**: review briefs should say explicitly to `git fetch
  origin main` (or equivalent) and diff against `origin/main`, never a
  possibly-stale local branch — cheap, prevents a real false alarm.
- **goal**: mutation-test the patch guard (remove the
  `narrow-pcall-zero-return` entry, confirm the canary test fails).
  **actually happened**: first attempt gave a FALSE PASS — removing the
  patch entry and rerunning `--make test` still passed, because the
  incremental build reused an already-patched `o/3p/tl/tl.lua` rather
  than regenerating it from the pin. Only a full `rm -rf o/3p/tl o/bin
  o/.groups o/_types` + refetch forced genuine regeneration, which then
  correctly caught the mutation.
  **contributed**: a real gap in the tree's incremental-build staleness
  tracking for a PATCHED third-party source — reverting the patch
  SOURCE doesn't invalidate the derived, already-patched build artifact
  the same way editing a first-party `.tl` file would. Same underlying
  mechanism the refine agent hit earlier this pass, from the other
  direction — two independent agents hit the same trap in one pass.
  **improvement**: filed below as «Sv9x_dXyj».

## candidates

- `take`'s silent fallback to a "reviewer" annotation instead of a clear
  refusal, on a plain `take` against a non-todo item that already carries
  a live claim — stays here for triage: needs gitboard's own maintainers/
  source, out of scope for this orchestrator session to fix directly.
- `brief research ID`'s generic "claim it as X" footer text not
  distinguishing a fresh pull from a rework handover — stays here for
  triage, same reason.
- `next`'s advisory output serving a stale cached view for at least one
  cycle after a sibling `spec` write lands — stays here for triage, same
  reason.
- research items with per-block numeric Result tables should name their
  scoring script's location for reviewer re-runnability — stays here for
  triage: candidate for `gitboard help bar` or `skills/work/decompose.md`
  wording, not urgent enough to file standalone mid-pass.
- `casts.md` class headings stating their discriminator explicitly —
  stays here for triage: a docs-sweep nice-to-have, not board-worthy
  alone.
- AGENTS.md should note `--make run <path>` requires `<path>` under
  the project root — stays here for triage.
- a research/refine brief whose deliverable is a large spec text should
  instruct the agent to also write it to a named scratch file, so a
  truncated completion notification has a documented recovery path —
  stays here for triage: candidate for `gitboard brief`'s own template.
- `gitboard show`'s guillemet-bracket handle form (`«CCB2_BBra»`, as
  rendered by the tool's own output) is rejected when pasted back in,
  despite docs claiming any divider/case works; bare handle and full
  ID both work — stays here for triage: needs gitboard's own source,
  out of scope for this orchestrator session.
- claim-then-spawn should be treated as one atomic step by the
  orchestrator: this pass silently dropped a review spawn after a
  successful `take --session review-...` call when a second
  notification arrived in the same turn — stays here for triage:
  candidate for a `gitboard help orchestrate` callout.
- the session scratchpad is not always empty at task start for a
  spawned agent (leftover files from a differently-scoped prior task) —
  stays here for triage: candidate for a one-line brief reminder to
  check for and move aside pre-existing scratch content.
- **filed as «Sv9x_dXyj»** (under `3ISJI4Lg`, the tl_patch mechanism's
  outcome): a `3p/*/tl_patch/*.tl` edit does not invalidate the
  already-unpacked, already-patched `o/3p/<name>` artifact — hit twice
  independently in this same pass (a refiner reverting a scratch patch,
  a reviewer mutation-testing a shipped one), and a third time
  historically (`aBAb_ePPu`, ended). `AGENTS.md` gets one sentence
  documenting the verified `rm -rf o/3p/<name>` + refetch incantation.
