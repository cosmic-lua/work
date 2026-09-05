# friction: 2026-09-05 work9-b (/work 9 --routine)

## orchestrator

- goal: open the friction log immediately after bootstrap/`sync`, before
  the first verb that selects work, per `skills/work/friction.md`'s
  ordering ("opened after the bootstrap and sync and before the first
  verb that selects work (`next`, `take`)").
  actually happened: ran `sync`, `show`, `next` (revealed a blocking
  unplaced triage item «mms6_eoOB», a prior pass's own friction log),
  `done mms6_eoOB`, `next` again, two `show`, and one refused `take`
  before creating this file. Cost: no rework, since none of those
  calls needed the log's presence to be correct — but it means this
  entry itself is written after the fact rather than as it happened.
  contributed: `skills/work/friction.md`'s ordering assumes a session's
  first verb is `next`/`take` toward BUILD work; this pass's actual
  first required action was resolving a blocking triage item
  (`next` refuses to advance past an unplaced root), which reads less
  like "selecting work" and more like bootstrap housekeeping, so the
  ordering rule didn't trigger a mental flag before it was already
  behind.
  improvement: `friction.md`'s ordering line could say explicitly that
  a triage resolution (`done`/`attach`/`compare` on a blocking unplaced
  item) counts as "the first verb that selects work" too — cheap doc
  fix, stays here for triage rather than filed standalone (one
  occurrence, not yet a recurring pattern).

- goal: reconcile the previous wave per `gitboard help orchestrate`
  step 1 (`sync`, then reconcile).
  actually happened: `show` reported `doing 0/10` — nothing in flight,
  nothing to reconcile, no PRs to merge, no reviews awaiting a verdict.
  `next` immediately named the blocking triage item «mms6_eoOB» (the
  prior pass's own friction log, filed unparented as its doctrine
  requires) rather than a todo/review action. Resolved by reading its
  full spec (already contained a complete ledger from the prior pass,
  including one filed countermeasure «Sv9x_dXyj» and several
  deliberately-unfiled "stays here for triage" candidates) and ending
  it with `gitboard done mms6_eoOB --reason completed`, matching the
  precedent of prior closed friction-log roots (`DyBP_Xlun`,
  `GDeh_uJY2`, both `role: root`, `resolution: completed`, ended
  without ever being placed via `attach`/`compare`).
  contributed: none — this is the friction-log lifecycle working
  exactly as documented (`friction.md`: "enters triage and the next
  refiner can attach, compare, or end it"); noting it here only because
  it consumed the pass's first ~6 tool calls before any board-forward
  progress was possible.
  improvement: none needed.

- goal: fill the wave with builds after triage cleared.
  actually happened: `show` reports `todo 204 (0 pullable)` — every
  single todo item across the whole board misses the spec bar right
  now. `next` names only the single highest-priority item lacking a
  bar-passing spec (`refine «keP3_sWNy»`); there is no verb to list the
  N highest-priority bar-missing items at once for parallel refining,
  so the second target (`LqNF_WKnL`) was found by reading the raw
  `todo` list `show` prints (priority-ordered) and checking the next
  entry's own `bar:` line by hand via `show LqNF_WKnL`.
  contributed: `gitboard help orchestrate`'s "Spare width goes to one
  or two refine/triage actions" assumes most of a wave's width goes to
  builds/reviews; with 0/204 pullable, that guidance under-uses a
  9-wide wave, but there is also no tool support for selecting a THIRD
  or later refine target without manually reading past `next`'s single
  recommendation — so more parallel refines would have cost more manual
  `show` probing per additional target, not just more Agent calls.
  improvement: none filed — followed the documented "one or two" cap
  literally since it is explicit doctrine, not an oversight; flagging
  here only as the reason this pass's wave went narrower than its width
  N=9 despite width being otherwise free. Stays here for triage: a
  `next --count N` (or similar) that names the top N bar-missing todo
  items at once would remove the manual `show`-probing step for a pass
  that wants to fill more of its width with refines when 0 items are
  pullable.

- goal: fill `<GAP>` in `gitboard brief refine ID`'s emitted body before
  handing it to an agent — the verdict line says only "fill <GAP>" with
  no further hint at what belongs there.
  actually happened: inferred from context (the placeholder sits right
  after the item's title, before "Current spec", inside a section
  titled "The task") that it should carry a plain-language statement of
  WHY the item misses the bar, sourced from `show ID`'s own `bar:`
  line, since a refiner otherwise has to re-derive that itself as its
  first action every time. No tool doc says this explicitly; confirmed
  by analogy with `brief builder`'s `<WORKTREE>`/`<BOUNCE_CONTEXT>`
  placeholders, which are similarly unexplained beyond their own names.
  contributed: `gitboard help brief`'s help text says placeholders are
  "board-known" and "filled" by the tool for most fields, but `<GAP>`
  and `<BOUNCE_CONTEXT>` are the two left to the orchestrator with zero
  guidance on their expected shape.
  improvement: `gitboard help brief` (or the brief's own comment above
  the placeholder) naming what `<GAP>` and `<BOUNCE_CONTEXT>` should
  contain would remove a guess every orchestrator currently has to make
  once and then repeat by convention. Stays here for triage — doc-level,
  not urgent.

## refine keP3_sWNy (general-purpose, background) — spec accepted, 579365ms wall, 56 tool calls

- goal (from its own report): confirm the proposed `@overload` lines
  parse under this repo's own annotation grammar before writing them
  into the spec as fact.
  actually happened: no system `lua` on PATH (`which lua` → exit 127);
  copied the ratchet test's ~220-line grammar-check section into a
  standalone probe and ran it under `cosmic`'s own bundled interpreter
  (`./bin/cosmic script.lua`) — ~10 tool calls to extract, wrap, and
  verify, after first trying (and failing) to invoke a plain `lua`.
  contributed: neither this repo's AGENTS.md nor cosmopolitan's notes
  that there is no system `lua` here, or that `cosmic` itself doubles
  as a Lua interpreter for exactly this kind of probe (`cosmic --help`'s
  "Standard lua options").
  improvement: worth a one-line AGENTS.md/brief note ("no system `lua`
  in this environment; `bin/cosmic <script>.lua` runs one directly") —
  stays here for triage, doc-level, cheap.
- goal: decide whether the item's "bump the pin" half needed a new item
  or could extend the existing, already-`blocked_by`-this-item sibling
  `vmX5_zQH2` (4-cast-site item, still scoped to all 4 including this
  one).
  actually happened: ~6 `show`/`find` calls to discover `vmX5_zQH2`
  already exists, already blocked on this item, and is stale-scoped
  (assumes all 4 sites close together, but 3 of its 4 already closed
  per its own evidence). Filed a new, narrower item (`vBk9_UxhS`, the
  pin-bump action alone) rather than reusing/re-scoping `vmX5_zQH2`.
  contributed: `show`'s "blocked by" field lists what blocks an item,
  but nothing surfaces the REVERSE (what an item blocks, beyond a plain
  count — `unblocks: N open item(s)` with no listing) at the point a
  refiner is deciding where new evidence belongs — a search was the
  only way to find the related sibling.
  improvement: `show ID`'s "unblocks: N" line could name the N items,
  not just count them — stays here for triage, needs gitboard's own
  source.
- orchestrator note (mine, not the agent's): reconciling this result,
  `vmX5_zQH2` is now confirmed over-blocked — 3 of its 4 cast sites
  (`bind`, `connect`, `connect.tl:95`) closed already per its own
  evidence and do not depend on `keP3_sWNy`/`vBk9_UxhS`, only the 4th
  (`socket.tl:437`) does. Its spec still reads as one all-4-sites
  `## Change`, so unblocking it now, as written, risks a builder pull
  attempting the un-closeable 4th site again. Re-scoping it (drop the
  4th site, unblock the rest) is a real, cheap fix but a full 3rd
  refine action, over this pass's "one or two" budget — left as-is,
  named here as the next refine pass's highest-leverage target.

## refine LqNF_WKnL (general-purpose, background) — spec accepted, 913935ms wall, 76 tool calls

- goal (from its own report): confirm the item's own frame (deciding
  `MVs4_UosO`'s fate) vs. its actual mandate (write `LqNF_WKnL`'s own
  `## Change`).
  actually happened: a careful re-read of the brief against the old
  spec's "## The question" wording before acting — no tool cost, a few
  minutes of reasoning; flagged that a one-line explicit mapping
  ("your Change describes the patch directly; MVs4_UosO's own spec is
  out of scope for you") would have removed the ambiguity up front.
  contributed: the old spec posed the decision in terms of a SIBLING
  item's fate, which reads ambiguously against "write THIS item's
  Change."
  improvement: stays here for triage — a refine-brief template note
  for this exact shape (a question posed in terms of a sibling item).
- goal: a first generation-1 build before any patch, to confirm a green
  baseline.
  actually happened: failed once (`remove_all: o/stage/cosmic:
  ENOTEMPTY`), fell back to the pinned release automatically; cost one
  extra build (~1 min). Traced to stale `o/` state predating this
  session, not anything the agent introduced.
  contributed: unclear — possibly leftover build output from an earlier
  process in this same container.
  improvement: none actionable from a refine session; flagged for a
  builder to eventually check why `o/stage/cosmic` wasn't clean at
  session start.
- goal: test a CANDIDATE patch entry (not yet in `3p/tl/tl_patch/`)
  against the real `bin/cosmic --check types` CLI end to end.
  actually happened: ~10 tool calls reading `_make/patch.tl`'s doc
  comments and D21 (which covers reversing an EXISTING patch, not
  trying a new one) before landing on the actual technique: edit the
  already-fetched `o/3p/tl/tl.lua` directly (safe, gitignored) and
  rebuild.
  contributed: D21/`guide.checking` document the reverse-a-patch
  workflow but not the try-a-new-candidate-patch one, even though both
  use the same underlying mechanism.
  improvement: a short line in D21 or `cosmic --docs guide.checking`
  ("testing a new candidate entry before it's committed: edit the
  fetched `o/3p/tl/tl.lua` directly and rebuild") — stays here for
  triage, doc-level, cheap, and this is the SECOND independent session
  (after `keP3_sWNy`'s own refiner hit an adjacent no-system-`lua` gap)
  to spend real tool calls rediscovering how to probe the patch/build
  layer from outside the tracked mechanism.

## orchestrator (continued) — filling remaining width with builds

Both refine targets cleared the bar and are file-disjoint from each
other (`cosmic-lua/cosmopolitan`'s `tool/net/definitions.lua` vs.
`cosmic-lua/cosmic`'s `3p/tl/tl_patch/integer.tl` + a new test file), so
rather than leave them for a future pass, claimed both (`take
keP3_sWNy --session build-keP3_sWNy-2305d922`, `take LqNF_WKnL
--session build-LqNF_WKnL-2305d922`), built fresh worktrees off
`origin/master`/`origin/main` per `take`'s own branch names, and
spawned two build agents from `gitboard brief builder ID`'s emitted
bodies. No friction: both `take` calls and both worktree creations
succeeded on the first attempt.

## review keP3_sWNy (general-purpose, background) — accept, auto-merge enabled, 424212ms wall, 37 tool calls

- goal: confirm the PR's single "build" check actually RUNS the test
  suite rather than merely compiling it (cosmopolitan has no separate
  test-run check to point at).
  actually happened: `get_check_run`'s `output.text` was empty and
  `get_job_logs` truncated hard on size in both directions (a
  `tail_lines=200` fetch missed the x86_64 section entirely; even
  `tail_lines=5000`/2.48M chars never reached it) — ~4 tool calls and
  several minutes before giving up on the log and proving it
  structurally instead, by reading `tool/lua/BUILD.mk:241-247` (the
  test target is a phony aggregate of `.ok` stamps, each produced only
  by actually running its test binary).
  contributed: cosmopolitan's own AGENTS.md says the correctness gate
  is `make ... o//tool/lua/test` but not that this target's own
  convention is "build and run in one step" (cosmic's AGENTS.md states
  this explicitly for its own gate, cosmopolitan's does not); separately,
  the log-fetch tool has no server-side grep, only local head/tail
  windows, which cannot usefully slice a log this large from either end.
  improvement: a one-line cosmopolitan AGENTS.md note stating the
  run-as-build convention for `o//tool/lua/test` — stays here for
  triage, doc-level, cheap. The log-fetch tool gap (no server-side
  grep) is out of scope for a board-doctrine countermeasure.

## build keP3_sWNy (general-purpose, background) — PR #383 opened, 373s wall, 24 tool calls

in=50 out=480 cache_read=1338240 cache_create=40231; by tool: Bash=16,
Edit=3, Grep=3, ToolSearch=1, mcp__github__create_pull_request=1;
first edit at call 6; 0 errors; one repeated read (x3
`tool/net/definitions.lua`, expected while confirming the edit
landed cleanly). Reported no friction worth logging: spec's line
numbers, evidence commands, and file state all matched the tree
exactly; mutation-tested the banned-fallibility-idiom guard cleanly on
the first try.

## review keP3_sWNy (general-purpose, background) — accept, auto-merge enabled, 424212ms wall, 37 tool calls

- goal: confirm the PR's single "build" check actually RUNS the test
  suite rather than merely compiling it (cosmopolitan has no separate
  test-run check to point at).
  actually happened: `get_check_run`'s `output.text` was empty and
  `get_job_logs` truncated hard on size in both directions (a
  `tail_lines=200` fetch missed the x86_64 section entirely; even
  `tail_lines=5000`/2.48M chars never reached it) — ~4 tool calls and
  several minutes before giving up on the log and proving it
  structurally instead, by reading `tool/lua/BUILD.mk:241-247` (the
  test target is a phony aggregate of `.ok` stamps, each produced only
  by actually running its test binary).
  contributed: cosmopolitan's own AGENTS.md says the correctness gate
  is `make ... o//tool/lua/test` but not that this target's own
  convention is "build and run in one step" (cosmic's AGENTS.md states
  this explicitly for its own gate, cosmopolitan's does not); separately,
  the log-fetch tool has no server-side grep, only local head/tail
  windows, which cannot usefully slice a log this large from either end.
  improvement: a one-line cosmopolitan AGENTS.md note stating the
  run-as-build convention for `o//tool/lua/test` — stays here for
  triage, doc-level, cheap. The log-fetch tool gap (no server-side
  grep) is out of scope for a board-doctrine countermeasure.

`keP3_sWNy` (cosmopolitan PR #383) end to end: build clean,
mutation-tested by both builder and reviewer independently (same
guard, same result), accept verdict, auto-merge enabled, merge
confirmed by GitHub notification, `gitboard done keP3_sWNy` closed it.
No rework needed — refine to closed board item in one continuous pass.

## build LqNF_WKnL (general-purpose, background) — PR #1726 opened, 518s wall, 58 tool calls

in=118 out=1668 cache_read=4672019 cache_create=83266; by tool:
Bash=37, Edit=4, Grep=5, Read=8, ToolSearch=1, Write=2,
mcp__github__create_pull_request=1; first edit at call 23; 1 error (a
`printf`-then-check probe exercising the gate-ON refusal path
deliberately — expected, not a real failure); 5 repeated
file-reads/reruns, all expected iterative-edit/gate-recheck cycles.
Reported friction: the `.cosmic-coverage` new-row format was resolved
in ~2 calls once the ratchet's own error message named the pattern;
one `pcall`-without-declared-return-type Teal warning cost one
edit/recheck cycle (worth a Teal-gotchas doc note); one fmt-stage
indentation mismatch fixed instantly via `--fix`.

## review LqNF_WKnL (general-purpose, background) — request-changes, one-line rework needed

`LqNF_WKnL` (cosmic PR #1726): thorough independent re-verification
(every measured claim reproduced, mutation test passed, diff scope
exact) but one concrete finding — `3p/tl/tl_patch/integer.tl:3`'s
header comment cites `docs/design/integer-strictness.md`, a file that
does not exist in the tree (it is `MVs4_UosO`'s still-blocked future
deliverable, not something this PR should assert already exists). No
friction from the review itself beyond needing `ToolSearch` to find
the GitHub MCP tools since `gh` isn't installed (cheap, ~2 calls) and
a short board-history detour to understand the dangling reference's
origin (~6 calls, informational, not a defect).

## build LqNF_WKnL rework round (general-purpose, background) — PR #1726 updated in place, 136s wall, 16 tool calls

in=34 out=555 cache_read=920157 cache_create=41691; by tool: Bash=9,
Edit=1, Read=2, Skill=1, ToolSearch=2,
mcp__github__add_issue_comment=1; first edit at call 6; 0 errors; one
repeated read of the patch file (expected, confirming the edit).
Spawned reusing the SAME claim (`build-LqNF_WKnL-2305d922`, per the
standing lesson from the prior friction log `mms6_eoOB` about reusing
the existing claim string across a rework cycle rather than minting a
new one) and the SAME worktree/branch (`3IpsjTFZ`, already pushed
once, PR #1726 stays open) — the builder brief's own
`<WORKTREE>`/branch boilerplate assumes a fresh pull ("branched off
the latest origin/main"), so this text needed hand-correction for the
rework case exactly as the refine `<GAP>` placeholder did earlier this
pass; same underlying tool gap, second occurrence, now three total
counting `mms6_eoOB`'s own hit — a recurring pattern, not a one-off.
Reported friction: the named review comment was a plain PR conversation
comment, not an inline review thread (`issuecomment-` vs.
`discussion_r` in the URL) — one `ToolSearch` call to confirm the reply
tool's schema wanted a different id shape than what was available;
resolved by posting a top-level PR comment instead.

## review LqNF_WKnL-r2 (general-purpose, background) — accept, auto-merge enabled, 275s wall, 29 tool calls

in=50 out=207 cache_read=1990305 cache_create=74381; by tool:
Artifact=1, Bash=17, Read=2, ToolSearch=2,
mcp__github__enable_pr_auto_merge=1, mcp__github__list_commits=1,
mcp__github__pull_request_read=5; no edit (review only); 1 error — an
`Artifact` tool call passed the bare GitHub PR URL
(`https://github.com/cosmic-lua/cosmic/pull/1726`) expecting it to
work like an artifact link; refused (`not an artifact URL`), one
wasted call, immediately recovered via the correct
`pull_request_read`/`get_comments` tools. Confirmed the round-1
reviewer's independent findings and the rework's one-line fix,
diffing `92597b1f` against `cd473c0a` directly to isolate exactly what
changed; mutation-tested the same guard, same result.

`LqNF_WKnL` (cosmic PR #1726) end to end: build → review
(request-changes) → rework (one-line fix, same branch/PR) → round-2
review (accept) → merge → `done`.

## orchestrator (continued) — self-inflicted session-name mismatch on round-2 review claim

goal: claim the round-2 review of PR #1726 after the rework push and
CI settling.
actually happened: minted a novel session string
(`review-LqNF_WKnL-r2-2305d922`, adding "-r2" to disambiguate from
round 1's review session) and `take` accepted it happily, recording it
as the `reviewer` field. Only when running `gitboard brief review
LqNF_WKnL` afterward did the emitted verdict command reveal it still
names the ORIGINAL round-1 string (`review-LqNF_WKnL-2305d922`, no
suffix) — `brief`'s minted name is deterministic from
`<kind>-<handle>-<orch8>` alone, with no round number, so my invented
"-r2" was gratuitous and left the emitted brief's own verdict command
pointing at a session string that no longer matched the actual
recorded claim. Caught before spawning (one `show` cross-check, ~1
extra tool call) and corrected by hand-editing every occurrence in the
brief text to the real claimed string before handing it to the review
agent.
contributed: nothing in `gitboard help orchestrate`/`help take` states
that a review session's minted name must be reused byte-for-byte
across review ROUNDS on the same item the way a rework's builder claim
must be (the `mms6_eoOB` friction log's lesson was specific to
builder/research claims persisting across rework rounds, not
explicitly to review-session naming on a second review round of the
same item) — I over-generalized "make it distinct" from the general
"distinct minted session name per agent" rule in `help orchestrate`
without checking whether ROUND already makes it distinct enough by
construction (it doesn't: `brief` mints from handle+orch8 only, so a
same-orchestrator second review of the same item gets the identical
string as the first, by design).
improvement: `gitboard help orchestrate` could say explicitly that a
review session's minted name is stable across multiple review rounds
of the SAME item within one orchestrator session (matching brief's own
deterministic minting), so a second `take` for round 2 should reuse
the exact string `brief` would emit, not invent a suffix — stays here
for triage, doc-level, one occurrence so far but directly caused by a
gap in the same doctrine area `mms6_eoOB` already flagged once.

## candidates

- a `next`-family verb (or a flag on `next`) that names the top N
  bar-missing todo items at once, for a pass that wants to fill spare
  width with parallel refines when 0 items are pullable — stays here
  for triage: needs gitboard's own source, out of scope for this
  orchestrator session.
- `friction.md`'s "opened before the first verb that selects work"
  ordering should say a blocking triage resolution counts as selecting
  work too — stays here for triage, doc-level, one occurrence so far.
- `gitboard help brief`/`brief builder`'s own template should
  distinguish a REWORK claim from a fresh pull: today the "Where to
  work" boilerplate always says "on a fresh branch, branched off the
  latest origin/main" and `<BOUNCE_CONTEXT>`/`<GAP>` are left fully
  blank with no hint of shape, even when `take` reports `state: rework`
  and a review verdict/PR/head already exist for the tool to fill in
  automatically. Hit THREE times now across this pass and the
  `mms6_eoOB` pass before it (a refine `<GAP>`, and now a rework
  `<WORKTREE>`/branch/`<BOUNCE_CONTEXT>` needing hand-correction) — a
  recurring pattern, not a one-off, and per `gitboard help bar`'s own
  enablement ranking ("a gate in core... transfers to every future
  session; prose does not") this is worth the tool's own maintainers
  prioritizing over further doc notes. Stays here for triage — needs
  gitboard's own source (plausibly `cosmic-lua/work`'s main branch,
  the "machinery beside" the item refs per `skills/work/SKILL.md`),
  out of scope for this orchestrator session to fix directly, and not
  yet measured enough (no line numbers, no read of that source) to
  file as its own spec-bar-passing item this pass.
- AGENTS.md/a brief note: no system `lua` binary exists in this
  environment; `bin/cosmic <script>.lua` runs an arbitrary Lua script
  directly and is the substitute — stays here for triage, doc-level.
- D21/`cosmic --docs guide.checking` should document testing a
  CANDIDATE (not-yet-committed) `tl_patch` entry: edit the fetched
  `o/3p/tl/tl.lua` directly and rebuild, safe since `o/` is gitignored
  — only the reverse-an-existing-patch workflow is documented today.
  Hit independently by two different refiner sessions this pass (one
  probing the annotation/grammar layer, one probing the patch/build
  layer) — a real recurring gap, not a one-off. Stays here for triage:
  doc-level, cheap, two independent hits.
- `show ID`'s "unblocks: N open item(s)" line should name the N items,
  not just count them, so a refiner deciding where new evidence belongs
  doesn't need `find`/`show` guesswork to discover a related, already-
  blocked sibling — stays here for triage, needs gitboard's own source.
- cosmopolitan's own AGENTS.md should state the run-as-build convention
  for `o//tool/lua/test` explicitly (cosmic's own AGENTS.md already
  does this for its gate) — stays here for triage, doc-level, cheap.
- `gitboard help orchestrate` should state explicitly that a review
  session's minted name is stable/deterministic across multiple review
  rounds of the SAME item (from `handle`+`orch8` alone, no round
  number) — an orchestrator claiming a round-2 review should reuse
  `brief`'s own emitted string, not invent a disambiguating suffix
  (caused one caught-before-spawn mismatch this pass). Stays here for
  triage, doc-level.
- `vmX5_zQH2` is over-blocked: 3 of its 4 named cast sites already
  close per its own evidence and do not depend on `keP3_sWNy`/
  `vBk9_UxhS`, only the 4th does — its spec still reads as one all-4
  `## Change`. Re-scoping it (drop the 4th site, unblock the rest) is
  cheap and high-leverage but a full 3rd refine action, over this
  pass's budget — stays here for triage as next pass's top refine
  target.

## pass summary

Triaged the prior pass's own friction log («mms6_eoOB», ended
completed — it had already filed its one bar-passing countermeasure).
Board opened at 0/204 pullable todo items and 0/10 doing, so the wave
held no builds/reviews to reconcile or start cold; refined the two
highest-priority bar-missing items («keP3_sWNy», «LqNF_WKnL», the
"one or two" doctrine width, file-disjoint across `cosmic-lua/cosmopolitan`
and `cosmic-lua/cosmic`), then — since both cleared the bar and stayed
disjoint — continued the same pass through claim, build, review,
merge for both rather than leaving them for a future pass:

- «keP3_sWNy» (cosmopolitan PR #383): build → review (accept) → merge
  → `done`. No rework needed. Split off a new item, «vBk9_UxhS»
  (pin-bump follow-up), correctly `blocked_by` this one.
- «LqNF_WKnL» (cosmic PR #1726): build → review (request-changes, one
  dangling doc reference) → rework (one-line fix, same branch/PR) →
  round-2 review (accept) → merge → `done`.

Both merges confirmed by GitHub notification before `done`. Both
sibling items that were `blocked_by` these two (`vBk9_UxhS`,
`MVs4_UosO`) auto-unblocked on `done` and are now todo/unpullable
(need their own refine) — left for the next pass, along with the
already-identified re-scope of the over-blocked `vmX5_zQH2`. Board
ends this pass at 0/10 doing, 0 triage, PRs #383 and #1726 merged, two
new items in the backlog (`vBk9_UxhS` filed this pass, plus the
newly-unblocked `MVs4_UosO`) waiting on refine.

No countermeasure in `## candidates` above reached the spec bar this
pass (all doc-level, none with a measured `## Change` against
gitboard's own source) — none filed standalone; the whole log below
enters triage unparented, per `friction.md`'s closing procedure.
