# friction: 2026-09-06 work9 (/work 9 --routine)

## orchestrator
- **goal**: fill a 9-wide wave with disjoint, ready builds via `gitboard next`.
  **actually happened**: `next` repeatedly surfaced the same three items
  (`Hkal_OAFy`, `4zwL_sOKR`, `QNQK_p3Wg`) as top pullable across ~6
  `next` calls even after claiming 6 unrelated items and after `rank
  ID --last` on two of them. `Hkal_OAFy`/`4zwL_sOKR`'s own spec text
  says "Ready when: <sibling item> is done AND a cosmos/tl release
  exists AND the pin is bumped" — none true yet (their prerequisite
  items were claimed, not merged, this same pass) — yet both pass the
  mechanical spec bar and show `[pullable]`. `QNQK_p3Wg` has an
  explicit "## Change: Not written" body and a same-file (`lunix.c`)
  sequencing note recommending it wait on `rhKJ_HSQd` (claimed this
  wave) — also `[pullable]`. ~8 extra `show`/`rank` tool calls spent
  establishing this rather than building.
  **contributed**: the spec bar checks section presence, not
  real-world readiness (a cross-repo release+pin dependency, or an
  explicit same-file sequencing note) — nothing in `gitboard help bar`
  covers either case, so an orchestrator has to open every candidate's
  full spec to catch it. `rank ID --last` only reorders within an
  item's own immediate sibling list, not against unranked siblings
  ("unranked sorts after ranked" per `help order`), so it did not
  demote `Hkal_OAFy`/`4zwL_sOKR` behind `QNQK_p3Wg`.
  **improvement**: teach the spec bar (or a new `next`-side check) to
  parse a "Ready when: X is done" precondition against the graph and
  withhold `[pullable]` until it holds — a gate, ranking above a doc.
  Passes the spec bar as a tool change, not filed this pass (out of
  scope for this session to design the parser); filed as a candidate
  below instead.
- **goal**: paste `gitboard brief builder rLV8_r8a5` verbatim into the
  agent prompt. **actually happened**: its step 4 ("Open the upstream
  issue" against `teal-language/tl`) is unreachable — this session's
  GitHub scope is `cosmic-lua/{cosmic,cosmopolitan,work}` only, no
  cross-org access — so I hand-edited the brief to add an environment
  note pointing the agent at AGENTS.md's own stated fallback (file in
  `cosmic-lua/cosmic` instead, or a direct reference). One edit, ~1
  minute.
  **contributed**: `gitboard brief` doesn't carry this session's
  GitHub-scope fact (it can't know it), and the item's spec, written
  by an earlier session under the same doctrine, still names the
  cross-org issue as the literal step — AGENTS.md's own carried-patch
  section already documents the fallback, so the fact exists in the
  tree, just not wired into the brief output.
  **improvement**: `gitboard brief` could append a standing environment
  note (same slot as the friction ask) whenever a spec step names an
  upstream repo outside this org — a doc-level fix (AGENTS.md already
  has the words) surfaced automatically over a per-orchestrator patch
  each time. Not filed as its own item — the countermeasure is "brief
  templates already include this class of note", too close to the
  `next`-readiness gate above to file as a second, competing tool
  change in the same pass; left for triage to fold into that one or
  split.
- **goal**: the live user, watching this pass, asked why briefs needed
  a `sed` strip and to file an item for an option instead.
  **actually happened**: filed `3Iw7Z3SC` ("gitboard brief: add
  --body-only to omit the trailing verdict line") under the same
  gitboard-tool outcome (`3HyRdT1JQS7pCPgF3sZi2Deo66q`) `Elus_cLzz` (a
  sibling, already completed) lives under. Traced the exact print
  sites (`_work/brief.tl:323-334`, `_work/gitgate.tl:31-37`) and the
  CLI wiring (`_work/gitcommands.tl:96-109`, `_work/gitboard.tl:230-240`)
  before writing the spec, ~10 tool calls.
  **contributed**: this is the same class of gap `Elus_cLzz` already
  fixed once (a brief's fixed output shape didn't match what an
  orchestrator actually needs to do with it) — a second instance of
  the same wrong turn, this time the verdict line instead of the
  missing friction ask.
  **improvement**: filed as its own item (see above) rather than
  folded into another spec's text — a gate (the flag) over a doc, per
  `help bar`'s own enablement ranking.

- **goal**: emit `hnlE_A39n`'s review brief and paste it verbatim.
  **actually happened**: its verdict-recording block reads `cd /home`
  then `bin/gitboard verdict ...` — `/home` has no `bin/gitboard` in
  this environment (it lives under `/home/user/cosmic/bin/` or
  `/home/user/cosmopolitan/bin/`), so a review agent following it
  verbatim would fail at the very last step, after doing all the real
  review work. Caught by reading the brief before dispatch; fixed with
  one edit (`cd /home/user/cosmic`).
  **contributed**: `_work/brief.tl:226-232`'s `product_root()` derives
  the checkout root as `dirname(dirname($GITBOARD_DIR))`, documented as
  correct because `bin/gitboard` normally exports `GITBOARD_DIR` itself
  as `<root>/o/board`. This session's bootstrap (`skills/work/SKILL.md`,
  the sibling-reuse path) instead set `GITBOARD_DIR=/home/user/work`
  directly (a sibling clone, not `<root>/o/board`) — exactly as that
  skill instructs when a sibling checkout exists — so
  `dirname(dirname("/home/user/work"))` computes `/home`, not a real
  product checkout. The skill's own documented shortcut and `brief`'s
  path-derivation assumption are incompatible; every review brief in a
  sibling-reuse session inherits this.
  **improvement**: `product_root()` gate-worthy fix — fall back to
  something more robust than dirname-dirness when `$GITBOARD_DIR`
  doesn't end in `o/board` (e.g. search upward from `$GITBOARD_DIR` or
  cwd for a directory holding `bin/gitboard`, or read an explicit
  `GITBOARD_PRODUCT_ROOT` the sibling-reuse bootstrap could export
  alongside `GITBOARD_DIR`). This recurs in EVERY review this pass and
  every future sibling-reuse session — filed as its own item (see
  ledger).
- **goal**: pull `8TDI_yqOV` again (now strongly re-evidenced — a
  third CI run, on a second unrelated PR, hit the identical 582 value)
  before ending this stretch of the pass. **actually happened**:
  refused twice in a row: first "2 diff(s) await a verdict... outrank
  this take" (my own dropped `A5NT_ilwk` review claim plus
  `VHkK_aA5k`'s never-claimed one), then, after re-claiming
  `A5NT_ilwk`'s review (holding rather than dropping this time), still
  refused on `VHkK_aA5k` alone — because `VHkK_aA5k`'s CI was actively
  running (the rerun I had just triggered on #389), and `take` refuses
  to let a review be CLAIMED while its CI runs, yet still counts it as
  "awaiting a verdict you can give" for the purpose of blocking a new
  pull. A live-CI review neither can be claimed nor can be dropped from
  the blocking set — the pull stays refused until that CI settles on
  its own, with nothing productive to do about it in the meantime.
  **contributed**: `take`'s two gates — the review-outranks-pull
  refusal, and the CI-running refusal on claiming a review — don't
  compose: the outranking check does not exempt an item whose review
  cannot currently be claimed for a structural reason (CI in flight),
  so the two refusals can sandwich a session with no legal move on
  either item until an external event (CI completion) resolves it.
  **improvement**: `take`'s outranking check could exempt a review
  whose CI is itself still running (the same condition that already
  refuses claiming it) — such an item cannot be acted on right now by
  definition, so it should not block other work either. A gate
  consistency fix, same shape as the earlier "claim succeeds where
  brief then refuses" finding; not filed as a separate item this pass
  (both are `take`'s review-gate not fully accounting for CI state —
  worth one combined item next triage rather than two overlapping
  ones).
- **goal**: review `A5NT_ilwk`'s PR #388 once CI settled after the
  one re-run. **actually happened**: `take` (the review claim)
  succeeded, but `brief review A5NT_ilwk` then refused
  ("CI has already concluded failure on this head") — the re-run
  failed AGAIN, on the identical `lfetch.c: covered 582, floor 585`
  value as the first failure. Posted a follow-up PR comment (the
  doctrine's one re-run was already spent) and dropped the review
  claim rather than hold it against a head that cannot be reviewed.
  Folded the identical-582-twice fact into `8TDI_yqOV`'s spec as a
  sharper hypothesis (CI-contention-specific, not pure randomness)
  before anyone pulls it — two `spec`/`take`/`drop`/comment calls.
  **contributed**: `take`'s review-claim gate checks only whether CI
  has SETTLED (0 of 1 vs done), not whether it settled GREEN — so a
  claim can succeed on a head that `brief` then immediately refuses to
  serve, a claim-then-immediately-drop round trip that costs one lock
  cycle for nothing actionable.
  **improvement**: `take`'s review-claim check could fold in the same
  "concluded failure" condition `brief` already tests, refusing the
  CLAIM instead of letting it succeed and dumping the refusal one step
  later — a small gate consistency fix; not filed as its own item this
  pass (low-frequency: only bites when CI settles red between `take`
  and `brief`, as it did here by coincidence of timing).
- **goal**: claim `hnlE_A39n`'s review under a session string, then
  emit its brief. **actually happened**: claimed under
  `review-hnlEA39n-2f92e512` (built by a bash `${id//_/}` substitution
  that strips underscores), but `gitboard brief review hnlE_A39n`
  generated a brief whose verdict command names
  `review-hnlE_A39n-2f92e512` (underscore preserved, matching the
  handle verbatim) — a mismatch that would have made the review
  agent's own `gitboard verdict ... --session review-hnlE_A39n-2f92e512`
  refuse against the actual claim. Caught by diffing the brief's
  session mentions against `gitboard show`'s `reviewer:` field before
  dispatch; fixed with one `sed`. This is the third time this pass a
  hand-built session string diverged from the tool's own mint format
  (`take`'s own claims for `A5NT_ilwk`/`rhKJ_HSQd`/etc. carried the
  same stripped-underscore shape, harmless there only because nothing
  else in those briefs re-quoted the session string back for an exact
  match).
  **contributed**: `orchestrate`'s doctrine says mint as
  `<kind>-<handle>-<orch8>` and that `brief KIND ID` "mints and prints
  [the exact string] on its own verdict line" — but the orchestrator
  minted its OWN claim session by hand before ever calling `brief`,
  instead of reading `brief`'s printed label first and claiming under
  that. Doing it in the doctrine's stated order (brief first, note its
  label, take under exactly that) would have prevented every instance.
  **improvement**: a habit fix (read the order in `help orchestrate`
  literally), not a tool gap — `brief` already prints the exact string
  to use; not filed as an item.

- **goal**: re-brief `hnlE_A39n` as a rework after its request-changes
  verdict, expecting `<BOUNCE_CONTEXT>` to auto-fill with the
  reviewer's finding (per `_work/brief.tl:203-217`'s documented
  purpose: save the orchestrator from hand-assembling rework context).
  **actually happened**: it stayed the literal, empty
  `<BOUNCE_CONTEXT>` placeholder. Traced why: `bounce_context()` looks
  up a formal GitHub PR REVIEW object in `CHANGES_REQUESTED` state
  (`gh.reviews`/`gh.latest_request_changes`), but the review brief I
  dispatched (`_work/brieftext_review.tl`, "Recording your verdict")
  instructs "request-changes: post the concrete gaps... as a PR
  comment" — a plain issue comment, not a formal review — so nothing
  matches. Hand-assembled the `REWORK` template's fields myself from
  the actual PR comment (`_work/brieftext.tl:115-132`'s shape) —
  ~4 tool calls (fetch the comment, read the template, fill it, verify
  the worktree/head still matched) instead of the near-zero cost the
  mechanism was built for.
  **contributed**: the review template's own instruction and
  `bounce_context`'s own lookup target are two different GitHub
  objects (an issue comment vs. a formal PR review) — nobody wired
  them to agree after `bounce_context` was added (a `_work/brieftext.tl`
  gap, not a `_work/brief.tl` one).
  **improvement**: gate-worthy — change the review template's
  request-changes instructions to post a formal GitHub PR review
  (`pull_request_review_write`, method create then submit_pending,
  state CHANGES_REQUESTED) with the findings as its body, instead of
  `add_issue_comment`. This makes `bounce_context` actually fire for
  every future request-changes verdict, the exact case it exists for.
  Filed as its own item (see ledger) — this recurs on every
  request-changes verdict, materially more often than either
  `product_root()` gap above.

## review hnlEA39n (sonnet) — request-changes, PR #1742, 384s, 41 tool calls, 3229475/1448/101170 (cache_read/out/cache_create)
- **goal**: point `bin/gitboard` at the real board and record a
  verdict. **actually happened**: `bin/gitboard init` silently created
  a fresh, empty local-only git repo at `o/board` instead of the real
  `cosmic-lua/work` clone the item lives in; `sync`/`verdict` gave no
  hint this was the wrong repo (`sync` said "state is current",
  `verdict` said "no item matches"). `_tool/friction.tl` confirms: 2
  command errors (`not a git repository: /home/user/cosmic/o/board`,
  then `no item matches 3IpBIhgrduVprYCYNlphnlEA39n`), `cd
  /home/user/cosmic` repeated 6x while diagnosing. Cost ~4 extra tool
  calls (init, sync, verdict-fail, then manually cloning
  `cosmic-lua/work` itself) before it worked — matching the agent's own
  account exactly.
  **contributed**: `gitboard init`'s help text ("prepare a state
  repository (a git repo, if needed)") doesn't say it fabricates an
  empty repo rather than cloning the real board when none exists at
  `--dir`; nothing in the review brief told this agent `GITBOARD_DIR`
  or an existing sibling clone to reuse — it started fully cold, unlike
  this orchestrator (which had the sibling-reuse bootstrap).
  **improvement**: (agent's own) either `gitboard init` clones
  `cosmic-lua/work` by default, or refuses with "no board found, clone
  it first" instead of silently fabricating an empty one — a gate over
  a doc. Not filed as a separate item this pass: this is a plausible
  duplicate/overlap of the general "review agents start cold, need
  board access" gap the `product_root()` item already partially
  covers; worth checking against that item during triage rather than
  filing a third overlapping one blind.
  Otherwise sound: the actual review work (scope check, CI read, the
  stale-prose finding) was correct and led to a legitimate
  request-changes verdict, once the board access was sorted out.

## rework hnlE_A39n (sonnet) — pushed fix, 115s, 15 tool calls, 1021975/53/52365 (cache_read/out/cache_create)
- **goal/actually happened**: clean, minimal rework — one prose clause
  fixed in `docs/design/casts.md`, gated, mutation-tested (mangled the
  heading text, confirmed `_build/cast_sites_test.tl` catches it,
  restored), pushed to the existing branch. No new PR opened, as
  instructed. `_tool/friction.tl`: 71 events, 15 tool calls (Bash=12,
  Edit=1, Read=2), first edit at call 5, zero errors, `casts.md` read
  2x (expected: read then verify after edit). Agent's own report:
  "None."

## review hnlEA39n2 (sonnet) — accept, PR #1742 auto-merge enabled, 271s, 34 tool calls, 2030904/450/54739 (cache_read/out/cache_create)
- **goal/actually happened**: independently re-verified the prior
  reviewer's findings plus its own fresh mutation test (a different
  mutation than the first review's), confirmed the rework's one prose
  fix was scoped correctly, and recorded accept. One real hiccup: its
  first `gitboard verdict accept` call lost a push race ("the mutation
  was dropped whole and the checkout re-synced") — almost certainly
  from colliding with this orchestrator's own concurrent `gitboard
  spec` calls updating `8TDI_yqOV` around the same window. Resolved by
  the tool's own suggested retry, one extra call. `_tool/friction.tl`:
  128 events, 34 tool calls (Bash=22, Edit=3, Read=1, ToolSearch=2,
  `pull_request_read`=5, `enable_pr_auto_merge`=1), first edit at call
  20, 1 other error (an `Edit` on an unread scratch file, self-corrected
  next call), `coverage/init.tl` read/edited 4x in its own scratch
  mutation-test copy (expected) and the verdict command run 2x (the
  race retry).
  **contributed**: normal, expected git-level contention between two
  concurrent `gitboard` writers (the orchestrator and a review agent)
  — the tool's own message named the fix precisely.
  **improvement**: none — this is the lock/retry mechanism working as
  designed, not a gap.

## build 8TDI_yqOV v2 (sonnet) — PR #390, 2034s (~34min), 63 tool calls, huge cache_read/129492 total tokens
- **goal/actually happened**: the spec (written by this orchestrator,
  weighted heavily toward "CI-contention-determinism" after 4 straight
  identical `582` values) told the builder to treat contention as the
  LEADING hypothesis. The builder tried it directly — ~25 CPU-burner
  runs, ~25 `taskset`-pinned single-core runs, ~40 tool calls — and it
  NEVER reproduced 582; contention was a dead end. What actually
  worked, unprompted by the spec, was decoding gcov's raw per-line
  JSON and diffing exact covered-line sets across runs, which took
  ~10 minutes once tried and fully explained every observed value
  (base 579 + a subset of 4 independent flaky branches, one gated on
  real network reachability to `httpbin.org`) with zero residual.
  Floor corrected to the true derived minimum (579, not an estimate).
  **contributed**: this orchestrator's own respec, built from strong
  but ultimately misleading correlational evidence (identical values
  don't imply contention-caused variance — they can equally mean a
  small, discrete set of branches with FIXED per-branch line deltas,
  which is exactly what was true), steered the builder toward ~40
  wasted tool calls before the productive technique. The spec's Change
  section suggested "make tests deterministic" and "lower the floor"
  as alternatives but didn't mention line-level gcov diffing at all —
  a technique this repo's own `line_coverage.lua` doesn't document
  anywhere either.
  **improvement**: the general lesson (worth carrying forward, not
  filing as a tool item): for a per-line coverage flake with a small
  number of DISCRETE observed values, diffing exact covered-line sets
  across runs is a more direct falsification/confirmation tool than
  environmental-condition correlation (identical repeated values are
  equally consistent with "a fixed small set of branches, present or
  absent" as with "environmental determinism") — a fact worth adding
  to `tool/lua/line_coverage.lua`'s own comments as a pointer for the
  next person debugging a coverage-floor flake, filed as part of the
  network-test follow-up below rather than a separate item.
- **goal**: file the builder's out-of-scope finding
  (`test_stream_https`'s live network call) as a new item.
  **actually happened**: filed it framed as an open test-hygiene
  question, then `gitboard find "test_stream_https"` (a check run
  before moving on, not prompted by any refusal) surfaced `mQ2B_8Pwr`
  (accepted, completed 2026-08-30) — which had ALREADY considered this
  exact test and explicitly ruled its self-skip design correct and
  needing "no policy decision." My first draft would have asked a
  future refiner to re-litigate a settled decision. Caught before
  causing damage (nobody had pulled it yet); corrected via one more
  `spec` call, narrowing scope to the genuinely new angle (coverage-
  floor accounting, which postdates `mQ2B_8Pwr` by a week).
  **contributed**: I filed from the builder's out-of-scope paragraph
  alone without checking whether the board already had history on the
  named test — `gitboard new`'s own "similar:" suggestions surfaced 3
  candidates (one of which was the answer) but I read them for
  duplication only after already writing and filing the first draft,
  not before.
  **improvement**: read every "similar:" item `gitboard new` surfaces
  BEFORE drafting a spec, not just before filing it — the tool already
  does the surfacing; the miss was sequencing (draft-then-check instead
  of check-then-draft). A habit fix, not a tool gap.

## review 8TDIyqOV (sonnet) — accept, PR #390 auto-merge enabled, 415s, 49 tool calls, 142788 total tokens
- **goal/actually happened**: independently re-verified the builder's
  root-cause (traced the 4 flaky branches directly in `lfetch.c`,
  7 local `MODE=cov` runs matching the claimed 586-592 range),
  mutation-tested the floor guard (999 → FAIL, restore → PASS), and
  judged the diff against the item's real intent rather than the
  spec's own leading hypothesis (explicitly noted the builder's
  gcov-diffing approach was BETTER than confirming CI-contention would
  have been). Recorded accept.
  **contributed/friction it found in its OWN process, not the repo**:
  cosmopolitan's build needs an unsandboxed shell (`compile.c`'s
  output-move semantics fail under the default sandboxed Bash tool,
  `failed to move output file` on the very first compile) — cost one
  failed build cycle before switching to `dangerouslyDisableSandbox`.
  Also self-inflicted background-job pattern issues (a manual `&` race
  with the harness's own `run_in_background`, then an imprecise
  `pgrep` pattern matching the wrong process) cost a few extra cycles.
  **improvement**: none of this is a repo or spec gap — it's
  environment/tool-usage friction specific to how a review agent's
  sandbox interacts with a from-scratch cosmopolitan build. Worth
  carrying as institutional knowledge for future cosmopolitan-repo
  agents (mentioned here, not filed as a board item — it's a fact
  about the harness a session operates under, not something the repo
  or gitboard can fix).

## review A5NTilwk (orchestrator hold, no agent spawned) — claimed then dropped
- this was the FIRST review claim on `A5NT_ilwk`, taken before its PR's
  CI had settled ("verdict when done consumes the claim"). CI then
  concluded failure (the `lfetch.c` flake, see orchestrator section)
  before any review agent was spawned under it. Dropped with a reason
  ("CI on head c7c27d1 is red on an unrelated flake... releasing until
  8TDI_yqOV's fix lands"), then re-claimed later under a differently-
  spelled session (`review-A5NT_ilwk-2f92e512`, see below) once CI was
  actually green. No agent transcript exists for this claim — it did
  no work beyond holding and releasing a lock; the full story is in
  the orchestrator section's "goal: review A5NT_ilwk's PR #388 once CI
  settled..." entries.

## review A5NT_ilwk (sonnet) — accept, PR #388 auto-merge enabled, 190s, 22 tool calls
- **goal/actually happened**: clean accept — fact-checked every claim
  against source, `make -n` dry-run diffed before/after (only a
  timing-annotation difference), and a well-targeted mutation test (a
  trailing backslash swallowing the following Makefile line into the
  comment — exactly the class of mistake a comment-only Makefile PR
  could actually make) confirmed the coverage flags would break and
  the fix restores them. Correctly treated the unrelated master-merge
  commit (the lfetch.c floor fix) as out of scope, per this session's
  own environment note. Agent's own report: "None" (no sandbox issue
  hit, dry-run only).

## review VHkK_aA5k (sonnet) — accept, PR #389 auto-merge enabled, 449s, 32 tool calls
- **goal/actually happened**: clean accept — fact-checked every claim
  (function signatures, dispatch behavior, annotation placement) in a
  fresh scratch worktree, mutation-tested by removing the new
  annotation and confirming the coverage ratchet's exact failure
  message, restored and reconfirmed green. Correctly treated the
  unrelated master-merge (lfetch.c floor fix) as out of scope. Hit the
  same `test_definitions_coverage.lua` wrong-path guess the spec itself
  carries (`tool/net/` vs. real `tool/lua/`) — third hit on the same
  underlying spec fact (builder and reviewer both, on this one item),
  resolved in seconds via `find`. Still not worth filing: one bad path
  string in one spec, not a systemic pattern.

## build A5NTilwk (sonnet) — PR #388, 337s, 17 tool calls, 971800/124/65293 (cache_read/out/cache_create)
- **goal/actually happened/contributed/improvement**: none. The agent's
  own report: "None worth logging. The spec's evidence (line numbers,
  file contents, `grep` output) matched the current tree exactly, so
  no re-derivation was needed... The one genuine mutation test
  available for a comment-only change — verifying the claimed link
  split via `make -n` in both directions — worked on the first try."
  `_tool/friction.tl` on its transcript: 75 events, 17 tool calls
  (Bash=12, Edit=2, Read=1, ToolSearch=1, PR-create=1), first edit at
  call 5, zero errors, one repeated command (`BUILD.mk` read twice,
  expected — two files edited under the same name in two directories).
  A clean pull: spec, evidence, and tree agreed throughout.

## build rhKJHSQd (sonnet) — STOPPED (falsified premise), 546s, 40 tool calls, 3172778/599/88676 (cache_read/out/cache_create)
- **goal**: implement `## Change` step 1, "build two new static `const
  struct MagnumStr[]` tables... mirroring the kIpOptnames-style tables
  `LoadMagnums` already reads."
  **actually happened**: stopped before any edit. The agent traced
  `MAGNUM_NUMBER`'s macro expansion and all four existing `LoadMagnums`
  tables back to their backing headers (~25 of its 40 calls, per its
  own account) and found `MagnumStr` encodes a byte OFFSET to an
  extern OS-resolved symbol's ADDRESS and dereferences it — valid only
  because all four existing families are real `extern int NAME;`
  objects captured via a link-time relocation in hand-written `.S`
  files (confirmed by an empirical GCC compile test showing the
  equivalent C literal is rejected: "initializer element is not
  constant"). Errno/signal constants are portable `#define` literals
  with no backing address; feeding one through the same scheme
  computes and dereferences a near-null address — a guaranteed SIGSEGV
  in `LuaUnix()` on every target OS, on interpreter startup. Also
  caught, independently, that the spec's own "100 errno entries" count
  (`grep -c 'LuaSetIntField(L, "E'`) silently includes 4 unrelated
  termios fields (`ECHO`/`ECHOE`/`ECHOK`/`ECHONL`); the real count is
  96. `_tool/friction.tl` on its transcript: 164 events, 40 tool calls
  (Bash=34, Read=6), no edits, 1 command error (a `wc -l` naming
  `tool/net/test_definitions_coverage.lua`, which doesn't exist at
  that path — the file's real location was never resolved before the
  agent stopped on the bigger blocker), one file read 3x
  (`lunix.c`, expected for a 5197-line file examined from several
  angles).
  **contributed**: the item's spec (written in an earlier refinement
  pass) proposed reusing `LoadMagnums`/`MagnumStr` for errno/signal by
  surface analogy to the four existing families ("mirroring the
  kIpOptnames-style tables") without tracing one of them back to its
  backing header to confirm the mechanism's actual precondition
  (extern symbol, not literal) — nothing in `magnumstrs.internal.h`
  states that constraint explicitly; it is implicit in every existing
  table being hand-written assembly.
  **improvement**: respec'd the item directly (this session, given the
  agent's own evidence was sufficient to design the fix — a plain
  `struct NameValue` array with literal initializers, no `MagnumStr`
  reuse) rather than dropping it bare for a future session to
  re-diagnose from scratch. Filed as its own respec, not a new item:
  the countermeasure IS the corrected spec now sitting in `todo`.
  Tool-level enablement candidate for triage: `gitboard help bar`'s
  "measured, not inferred" rule already asks a refiner to run the
  command that produces a claimed number — this spec's grep WAS run
  and pasted, but the pattern itself was under-specific (matched 4
  false positives) and nothing caught it before the item passed
  refinement; a lint on `Evidence` sections for count-claims whose own
  named grep pattern is broader than the claim (e.g. `'LuaSetIntField(L,
  "E'` matching non-errno fields) is a candidate, not filed here —
  narrow and probably not worth a general-purpose check for one
  pattern-quality mistake.

## build hnlEA39n (sonnet) — PR #1742, 755s, 65 tool calls, 6736502/1441/112434 (cache_read/out/cache_create)
- **goal/actually happened**: agent's own account: implemented the
  spec's literal worked example (a narrow `CoroutinePatch`/`OsPatch`
  record with an `as` cast) first, then discovered — from the
  Evidence section's own numeric claim (`coverage/init.tl` 4→2) — that
  a retargeted cast still counts as a cast line under
  `_build/casts.tl`'s definition, so that reading couldn't be the
  intended fix; the actual fix is zero casts (direct field assignment
  onto the already-typed `coroutine`/`os` globals type-checks with no
  cast at all). ~10 minutes and 2 edits spent on the false start before
  backing out. `_tool/friction.tl`: 254 events, 65 tool calls (Bash=48,
  Edit=5, Read=9, Grep=1, ToolSearch=1, PR-create=1), first edit at
  call 8, 2 command errors (both expected probe-script failures used
  to test the Teal checker's nominal-record and unused-argument rules
  — not real errors), `coverage/init.tl` touched 8x and `casts.md` 2x
  (both expected for a multi-step edit-then-verify cycle on the same
  two files).
  **contributed**: the spec's Change section's own worked example
  ("record CoroutinePatch...") pointed concretely at the record
  approach without flagging that the field's own already-declared type
  might accept the value directly with no cast — a reading compatible
  with the prose ("declare the narrower type... instead of widening")
  but not what the prose's one example showed.
  **improvement**: per the agent's own suggestion — a spec whose worked
  example admits a simpler unstated alternative should say so ("the
  narrower type may be the field's own already-declared type — no cast
  needed"), a refiner-side phrasing habit, not a tool or gate; not
  filed as a standalone item (one occurrence, on a spec instance that
  is now built and gone — nothing recurring to gate).

## build VHkKaA5k (sonnet) — PR #389, 885s, 33 tool calls, 1997300/540/84095 (cache_read/out/cache_create)
- **goal/actually happened**: clean pull, mechanical implementation
  matching the spec. One repeated wrong-path guess: `wc -l ... tool/net/test_definitions_coverage.lua`
  failed (file doesn't exist there — it's `tool/lua/test_definitions_coverage.lua`,
  confirmed by `find` this session); the agent's own report doesn't
  flag it as friction, but the same wrong path recurred in
  `rhKJ_HSQd`'s independent transcript below — both items' specs name
  this file (`VHkK_aA5k`'s Change: "`test_definitions_coverage.lua`'s
  existing `add(...)`"; `rhKJ_HSQd`'s: "`test_definitions_coverage.lua`'s
  existing `LoadMagnums` scan") without its directory, and both agents
  guessed `tool/net/` by analogy to `definitions.lua`'s own location
  rather than its real `tool/lua/`. Cheap each time (one failed `wc -l`,
  immediately corrected via `find`/`grep`) — not filed as a
  countermeasure: both specs were written in the same earlier
  refinement pass (one shared authorial gap, not an independent
  pattern), and the cost per hit was under a minute.
  `_tool/friction.tl`: 138 events, 33 tool calls (Bash=25, Edit=3,
  Read=2, Grep=1, PR-create=1), first edit at call 13, 1 command error
  (the path guess above), `definitions.lua` touched 3x and `lzip.c` 2x
  (expected for locating each annotation/registration point then
  editing it).

## build 8TDIyqOV (sonnet) — STOPPED, no PR (correctly — see respec), 897s, 11 tool calls, 665285/1486/47279 (cache_read/out/cache_create)
- **goal**: stabilize `lfetch.c`'s flaky line coverage per the spec.
  **actually happened**: found `3IvOz0wC`'s own PR already carries a
  second commit lowering the floor to 585 with a rationale comment,
  ran `MODE=cov` 9 times (590 x6, 586 x2, 592 x1 — all >= 585), and
  concluded the item was already resolved, recommending closure. This
  session's independent evidence (PR #388's real CI run hitting 582,
  *below* the 585 floor, the same day) falsifies that conclusion — the
  fix landed but is incomplete, and the item was respec'd rather than
  closed (see orchestrator's respec above).
  **contributed**: the agent's own account: the item's Evidence
  quoted "committed at 590" — true only briefly during `3IvOz0wC`'s own
  PR review, stale by the time this item was dispatched. Separately (not
  named by the agent, found by this session): 9 local runs in a quiet
  container undersampled the true variance CI's noisier runner exposes
  — local reproduction reaching only 586-592 was read as confirmation
  the floor holds, when it was actually just too few, too-quiet
  samples.
  **improvement**: (agent's own) a board item derived from a
  still-open PR's evidence should be re-diffed against that PR's FINAL
  merged state before dispatch — a refiner-side or `next`-side check,
  not filed here (same shape as the "Ready when" gate already
  candidated above — a fact outside the tree, here "has this PR's
  evidence source since changed," folds into the same parser). Second,
  now-demonstrated finding worth carrying into the respec (done): a
  local-only reproduction loop is not sufficient evidence that a CI
  flake's floor holds — this session's own real CI failure the same
  day is stronger evidence than 9 quiet local runs.

## build rLV8r8a5 (sonnet) — STOPPED (file-cap collision), no PR (correctly — see respec), 766s, 61 tool calls, 5595718/488/121651 (cache_read/out/cache_create)
- **goal**: implement the pcall-return patch and canary as specced.
  **actually happened**: traced the mechanism correctly (confirmed the
  zero-arity subclass is already fixed by PR #1725, confirmed the
  remaining sites' real gap is narrower than the spec's blanket
  framing, confirmed an `any`-typed callee already hard-fails
  independent of pcall) — then stopped when both anchor files
  (`teal_test.tl` at exactly 500, `narrow.tl` at 467/500 needing 54)
  had no room for the required additions. Drafted the actual patch
  entry into a scratch file and `wc -l`'d it to size the gap precisely
  rather than guessing.
  **contributed**: PR #1725, landed after this item was last refined,
  consumed exactly the headroom this item's Change assumed was
  available in both files it was told to edit — a second instance
  (after `rhKJ_HSQd`'s `LoadMagnums` mismatch and `8TDI_yqOV`'s stale
  floor) of a spec whose facts moved between refinement and pull.
  `_tool/friction.tl`: 246 events, 61 tool calls (Bash=51, Read=10),
  no edits, 6 command errors (4 are DELIBERATE probe-script failures
  used to test the checker's own typing rules — not real errors; 1 is
  a genuine `Read` call malformed as non-JSON input, worth noting as a
  tool-usage slip, self-recovered next call; 1 more probe error),
  `o/3p/tl/tl.lua` read 6x (expected — tracing one handler through a
  5000+-line fetched file from several angles).
  **contributed (respec-worthy, not the agent's own words)**: this is
  the THIRD item this pass whose spec's facts had moved by the time it
  was pulled (`rhKJ_HSQd`: mechanism misapplied; `8TDI_yqOV`: floor
  already partially fixed; `rLV8_r8a5`: headroom already consumed) —
  all three respec'd this pass rather than left dead. The pattern is
  real: this outcome's own census of cast/binding sites was refined in
  bulk on 2026-08-26/09-03 and items are being pulled 1-3 weeks later,
  after sibling PRs in the same area landed and changed the ground
  facts. See the `next`-readiness candidate above — the same
  "Ready when" mechanism (a command whose output means the spec's
  premises still hold, checked before offering `[pullable]`) would
  catch a stale premise, not just an unmet cross-repo dependency;
  worth widening that candidate's scope when it's next refined, rather
  than filing a second, overlapping tool item.

## candidates

- `gitboard brief`: add `--body-only` to omit the trailing verdict
  line — filed as `3Iw7Z3SC` (cosmic-lua/work).
- `_work/brief.tl`'s `product_root()` breaks (`cd /home`) under the
  documented sibling-reuse `GITBOARD_DIR` shape — filed as `3Iw9SDVR`
  (cosmic-lua/work).
- Review brief's request-changes instructions post a plain PR comment
  instead of a formal GitHub PR review, so `bounce_context()` never
  auto-fills a rework brief — filed as `IB9Z_CwM4` (cosmic-lua/work).
- `test_fetchstream_edge.lua`'s `test_stream_https` live network call
  and its interaction with the NEW line-coverage floor gate (not its
  already-settled self-skip design) — filed as `XvG7_47u0`
  (cosmic-lua/cosmopolitan), corrected mid-pass after `gitboard find`
  surfaced the prior settled decision (`mQ2B_8Pwr`) it must not
  re-litigate.
- `next`'s `[pullable]` marking doesn't check a spec's own "Ready
  when: X is done" precondition against the graph, and doesn't detect
  a stale premise (a fact the spec relied on that has since changed
  upstream) — hit THREE times this pass (`rhKJ_HSQd`, `8TDI_yqOV`,
  `rLV8_r8a5`, each respec'd rather than dropped bare). Stays here for
  triage: no concrete `## Change` written (the parsing/detection
  design isn't settled), so it doesn't pass the spec bar yet — a
  refiner should size it as its own item, likely split into "Ready
  when" parsing and "stale premise" staleness-detection as two
  candidates once scoped.
- `take`'s review-claim gates don't fully account for CI state: a
  claim can succeed where `brief` then immediately refuses (CI already
  concluded failure), and the review-outranks-pull refusal doesn't
  exempt a review whose CI is actively running (unclaimable and
  unexemptable at the same time). Stays here for triage — two related
  but distinct gate-consistency gaps in the same verb, worth one
  combined item once scoped rather than two overlapping fixes.
- `gitboard init` fabricates an empty local `o/board` instead of
  cloning the real board when none exists at `--dir`, with no warning
  — hit by a review agent starting fully cold. Stays here for triage:
  likely overlaps the `product_root()` item's broader "review agents
  need board access wired in" territory; check before filing separately.

