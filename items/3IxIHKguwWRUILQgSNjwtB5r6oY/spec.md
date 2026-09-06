# friction: 2026-09-06 work5-routine (/work 5 --routine)

## orchestrator

- **goal**: pull the top-ranked disjoint item («0oBN_Fa6X»,
  gentype_defs.tl/zip circular dependency) and mint its builder brief.
- **actually happened**: `gitboard brief builder 0oBN_Fa6X` and every
  other brief in this wave printed `You are a builder agent for
  \`cosmic-lua/work\`` and told the agent to open its PR against
  `cosmic-lua/work`, even though the item's own spec is entirely about
  `cosmic-lua/cosmic` files (`_types/gentype_defs.tl`, `cosmic/zip.tl`).
  `gitboard show` confirmed these items carry no `repo:` field at all.
  Caught before the first agent pushed anything, but only because the
  file paths in the spec were checked against both repos by hand (2
  `ls` calls); cost ~1 extra tool round plus a follow-up correction
  message to the already-spawned «0oBN_Fa6X» agent, which had already
  been given the wrong repo in its first prompt.
- **contributed**: `gitboard new`/`help set` document that an
  unset `--repo` defaults to "the board's origin" (`cosmic-lua/work`
  itself), a sensible default for board-tooling items but silently
  wrong for the far more common case of items about the board's own
  primary served repo, `cosmic-lua/cosmic`. Nothing in `brief`'s output
  flags "this item has no repo tag, defaulting to X" — the wrong repo
  name is printed with the same confidence as an explicitly-set one.
  Two more items pulled later this same wave (`70P4_YBPd`, `zAjL_PBPK`)
  had the identical gap, both siblings under the same parent
  (`3HyRcd9F` / handle `w2IX_bnGA`) — consistent with that parent's
  batch of children having been filed without `--repo` in one pass.
- **improvement**: a gate, ranked highest per `gitboard help bar`: `new`
  (or a `fsck` check) should refuse — or at minimum loudly flag — an
  item whose spec body names files that don't exist in its resolved
  repo (`cosmic-lua/work`'s tree lacks `cosmic/`, `_types/`, `_cli/`
  entirely, so this is a cheap, no-false-positive check for any item
  whose spec contains a path under those roots). Short of that,
  `brief`'s own output should say plainly when it is printing a
  defaulted repo rather than an explicit one, so an orchestrator sees
  the gap before spawning rather than after. Filed as a candidate below
  rather than fixed here — it is a `gitboard` change, not a board-item
  fix, and out of this pass's own scope. In the meantime, repaired
  the three affected items directly with `gitboard set <id> --repo
  cosmic-lua/cosmic` before/immediately after claiming each.

- **goal**: spawn the «0oBN_Fa6X» builder into the manually-created
  worktree `/home/user/wt-3Iwc0zaT` (needed because the item's board
  branch, `3Iwc0zaT`, must match exactly for the later push/PR).
- **actually happened**: the Agent call was made with `isolation:
  "worktree"`, which auto-sandboxes the agent to its OWN separate
  worktree (`/home/user/cosmic/.claude/worktrees/agent-<id>`) — a
  directory the agent cannot `cd` out of; its Bash tool refuses any
  command that changes into a different checkout. A same-turn
  `SendMessage` telling the agent to "ignore the isolated worktree and
  use `/home/user/wt-3Iwc0zaT` instead" did NOT fix this — it is a
  hard sandbox boundary, not a preference the agent can be talked out
  of. The agent tried `EnterWorktree` (rejected — needs approval no
  one was watching to give) three times, then went silent. It sat idle
  for the remaining ~4 hours of the pass (19 events total, 3 tool
  calls) until this orchestrator noticed via `ListAgents` that it was
  still "running" long after every sibling build had finished in
  10-15 minutes, and killed it (`_tool/friction.tl` on its transcript:
  `wall=14918s`, 2 of its 3 tool calls errored). Its board claim,
  unrenewed for hours, crossed the hour lease and was legitimately
  re-claimed by an unrelated, independently-scheduled orchestrator
  session (`build-0oBN_Fa6X-748ecc95`) partway through, which is who
  actually finished the item — visible only because that session's
  own commits/claims carry a different `<orch8>` than this one's.
  The «70P4_YBPd» review agent hit the identical sandboxing wall from
  a different angle: told to "clone fresh... never reuse another
  agent's worktree," it tried to `cd` into its own scratch clone
  directory and was denied 18 times in a row (identical command,
  identical rejection) before going equally idle for hours — though
  it had already posted its real review verdict (`request-changes`,
  10:59) before getting stuck on the mutation-test follow-up, so its
  core output was not lost, just its natural exit.
- **contributed**: `isolation: "worktree"` is the wrong tool whenever
  the agent's target worktree/branch is dictated externally (here, by
  `gitboard take`'s own branch-naming contract) rather than left to the
  agent to choose — the two worktree-creation mechanisms cannot be
  reconciled after the fact by instruction, only by not invoking the
  automatic one in the first place. Separately: an agent that hits a
  hard tool refusal and then a denied permission request has no
  self-timeout — it goes quiet rather than reporting the blocker and
  stopping, so nothing signals the orchestrator except the absence of
  a completion notification, which is not itself a visible event.
- **improvement**: (ranked per `gitboard help bar`) process discipline
  over a tool change: never pass `isolation: "worktree"` when a
  specific pre-created worktree path is being handed to the agent in
  its brief — the two are mutually exclusive, not composable via a
  follow-up message. If caught only after the mismatched spawn (as
  here), stop and respawn immediately rather than trying to redirect
  the running agent — the redirect message cost nothing to send but
  gave false confidence that the problem was fixed, when the fix
  needed to be a kill-and-restart from the first sign of the sandbox
  refusal, not four hours later. A background-agent liveness check
  (e.g., "no tool call in N minutes" as itself a surfaced signal,
  independent of a completion notification) would have caught both
  stuck agents in minutes instead of hours.

## build 0oBN_Fa6X (Sonnet 5) — orchestrator error, killed after 14918s, 3 tool calls, 6in/33out/92503cr/49485cc tokens

- **goal**: bump `_types/gentype_defs.tl` off `cosmic.zip` to break the
  zip type-generation bootstrap's circular dependency.
- **actually happened**: never got to work the spec at all — spawned
  with `isolation: "worktree"` (this orchestrator's own error, detailed
  in the orchestrator section above) into a sandbox it could not `cd`
  out of. One `Bash` `cd /home/user/wt-3Iwc0zaT && ...` refused by the
  tool itself, three `EnterWorktree` attempts refused for lack of
  approval, then silence for the remainder of the pass. Killed by the
  orchestrator ~4h50m after spawn once noticed via `ListAgents`; the
  item's claim had long since crossed the hour lease and was picked up
  and finished by an unrelated, independently-scheduled orchestrator
  session in the meantime.
- **contributed**: entirely orchestrator-side (see above) — nothing in
  this item's own spec or brief was at fault.
- **improvement**: none owed by this item; the countermeasure is filed
  against the orchestrator's own tool use, above.

## review 70P4_YBPd (Sonnet 5) — verdict recorded then stalled, killed after 13760s, 26 tool calls, 48in/254out/1383285cr/45889cc tokens

- **goal**: fresh-context adversarial review of PR #1744 against
  «70P4_YBPd»'s spec.
- **actually happened**: completed its actual job well within the
  first two hours — cloned fresh, ran `bin/cosmic --make ci` green,
  mutated the `is_binary` guard and watched the new test catch it,
  restored it, then correctly caught a real gap outside the diff's own
  scope (`docs/guides/lint.md`'s file-length section left stale, same
  class of staleness the PR itself fixed in `quickstart.md`) and
  recorded `request-changes` with that finding quoted file:line — all
  of this by 10:59, visible independently via the PR's own comment
  timestamp. It then continued past that point into a stuck retry loop
  — 18 identical, identically-rejected attempts to `cd` into its own
  scratch clone directory for a follow-up check — and went idle for
  the remaining ~1.8 hours until this orchestrator killed it.
- **contributed**: the brief's "Final report" section names what to
  report but not an explicit stopping point after `gitboard verdict`
  is recorded — nothing in the brief tells the agent its job is DONE
  once the verdict call and PR comment succeed, so it kept finding more
  to verify and eventually wedged on a permission wall instead of
  wrapping up.
- **improvement**: (ranked per `gitboard help bar`) a brief-text fix:
  state explicitly, right after the verdict-recording command block,
  that recording the verdict and posting the PR comment ARE the
  deliverable — stop immediately after, do not continue probing. Cheap
  relative to a stuck agent burning hours of wall-clock for zero
  additional signal.

## build zAjL_PBPK (Sonnet 5) — bounced, 135s, 17 tool calls, 36in/231out/1003295cr/51091cc tokens

- **goal**: add one sentence to AGENTS.md's Testing section immediately
  after the parent item's quoted "existing" anchor line.
- **actually happened**: stopped before any edit. `grep -n "check
  types" AGENTS.md`, a full read of lines 339-384 (the actual Testing
  section), and `git log --all -p` for the phrase all confirmed the
  quoted anchor line never existed in AGENTS.md, in the current tree or
  its history. 17 tool calls (6 Bash, 7 Grep, 4 Read), ~135s wall, one
  repeated read of the same file. Verified independently by the
  orchestrator afterward (`grep -n "check types" AGENTS.md` →
  one hit, line 111, under "Language and Conventions", unrelated).
- **contributed**: the item's own `## Change` quoted, as "the existing
  ... line" in AGENTS.md, a sentence that is actually the generic
  builder-agent workflow boilerplate every board brief carries ("Between
  edits, `bin/cosmic --check types <file>`...") — the spec's Evidence
  section appears to have been written by conflating that boilerplate
  with real repo content, and nothing in refinement cross-checked the
  quoted "existing" line against the file before the item was queued as
  pullable.
- **improvement**: (ranked per `gitboard help bar`) a gate — `spec`/the
  refine flow could require any "existing line" an item's Change
  section anchors against to carry a `grep`-verified `file:line`
  citation at spec time, not a recalled quote, catching this class
  before an item ever reaches todo. Filed a child item
  («lq6z_JMiX») under the parent with this finding and dropped the
  claim (converted to container) rather than force an edit against a
  spec that turned out false; no diff was made, nothing to leave on the
  branch, worktree and branch removed.

## build 4zwL_sOKR (Sonnet 5) — bounced, 590s, 51 tool calls, 104in/540out/4157753cr/90250cc tokens

- **goal**: bump the cosmos pin to the release carrying `unix.E`/
  `unix.SIG`, then close `errno.tl`/`quicksand/proc.tl`'s four
  constant-lookup casts against the new typed maps.
- **actually happened**: verifying the item's three "Ready when"
  conditions took ~15 tool calls (git log/tag/merge-base in a second,
  cosmopolitan checkout, plus GitHub MCP calls for the release), since
  none is checkable from the cosmic worktree alone. The pin bump then
  broke an unrelated file (`cosmic/net/init.tl`'s `socket_pair`, ~10
  minutes to trace to cosmopolitan#385 landing in the same pin range)
  before the real blocker surfaced: `unix.E`/`unix.SIG` generate as
  bare `table`, confirmed with two intentionally-failing type-check
  probes (both logged as "errors" above — expected, diagnostic, not
  mistakes) rather than trusting a source-level regex read. First edit
  at call 21; 51 calls total, ~10 minutes wall.
- **contributed**: the spec's readiness conditions point at facts, not
  at which repo/tool answers each one. The real blocker —
  `_types/gentype_parse.tl`'s `@type`-tag parser truncating
  `table<K,V>` to bare `table` — has zero existing test coverage
  (`gentype_test.tl` tests the underlying `convert_type` conversion in
  isolation but never through a `@type` field annotation), so nothing
  caught it before this item was queued as pullable spec-bar-passing
  work built on a false premise.
- **improvement**: (ranked per `gitboard help bar`) a gate — add the
  missing `@type table<K,V>` round-trip test to `_types/gentype_test.tl`
  itself, which would have caught this at the tool's own development
  time rather than at build time on an unrelated item, three items deep
  (this one, «0Svo_ZeTH», and by extension anything else annotated
  `table<K,V>`). Filed the fix as its own item, «RNb7_b0tV», parented
  under this item's own parent («F1i3_VNKE») since it blocks multiple
  siblings there, not just this one; filed a child under this item
  itself pointing back to it and to the real, committed (unpushed) WIP
  on branch `3Iw4Klc9` a respec should resume from rather than redo.
  Converted to container, claim released.

## build 70P4_YBPd (Sonnet 5) — PR #1744 opened, 503s, 45 tool calls, 92in/1540out/3266893cr/67415cc tokens

- **goal**: skip `--check lint`'s file-length rule on NUL-containing
  (binary) files, per the spec's exact site and message-wording
  instructions.
- **actually happened**: clean run, no errors, no stuck point. First
  edit at call 7; repeated reads of the two touched files and one
  `wc -l` re-check are normal iterate-and-verify, not friction. Full
  `bin/cosmic --make ci` green (289 checks, 3341 tests). Mutation-tested
  the new `is_binary` guard by flipping its sense, watched 5 tests fail
  including the new one, restored, re-verified green.
- **contributed**: n/a — the agent's own account: "None. The spec was
  precise and self-contained: the exact site, line, and message
  wording to keep/drop were all named, and `wc -l` upfront confirmed
  plenty of headroom under the 500-line cap for both touched files."
- **improvement**: none needed; recorded as a clean comparison point
  against this pass's other, bounced builds — the difference being a
  spec whose every referenced line was verified to actually exist.

## build rLV8_r8a5 (Sonnet 5) — bounced, 779s, 56 tool calls, 114in/2592out/5456638cr/116407cc tokens

- **goal**: draft and land the `narrow-pcall-return` tl patch entry
  widening a known-signature, non-zero-arity `pcall(f,...)`'s slot 2
  to close `sqlite/extras.tl`'s 2 remaining casts.
- **actually happened**: ~13 minutes of probe scripts (10-14 calls
  each, 3 iterations) to confirm the widening's shape, then ~13 more
  minutes discovering via `--check types cosmic/shm.tl` and a full
  `--make check` that the same widening — scoped by the spec to "only"
  2 sites — actually changes every non-zero-arity `pcall(known_fn,...)`
  call's type tree-wide, breaking 6 sites in `shm.tl` plus
  `_make/policy_test.tl:376`, `_eval/score_test.tl:143`,
  `_fuzz/shrink.tl:41`. 56 tool calls total, ~13 minutes wall,
  first edit at call 29.
- **contributed**: the item's own Evidence cited a PRIOR builder having
  drafted the same ~54-line entry and stopped at the line-count/headroom
  finding, without ever having run it against the full tree — the
  isolation assumption was inherited as fact, not re-verified, until
  this builder actually applied the patch and ran `--make check`. Worth
  noting: a SIBLING item, «nG3p_QYHj» (already `accept`ed, PR #1725),
  had already diagnosed this EXACT class of tree-wide regression for
  the zero-return-arity subclass and rescoped to it for that reason —
  this item's own respec evidently didn't carry that precedent forward
  when it moved to the non-zero-arity subclass.
- **improvement**: (ranked per `gitboard help bar`) since Teal has no
  `ok`-keyed discriminated-tuple narrowing, a find/replace patch on the
  shared `special_pcall_xpcall` handler cannot express a call-site-scoped
  type change — this is a structural limit of the `3p/tl_patch/`
  mechanism, not a drafting error, so the real fix is either a materially
  larger checker feature (own decision record) or accepting the 2 sites
  keep their casts. Filed as child «IOA7_CLf5» with the full regression
  evidence and the resolved patch-entry naming/sort-order gotcha
  (`narrow-pcall-return` sorts before, not after,
  `narrow-pcall-zero-return` — global sort order across the whole
  `tl_patch/` directory, not per-file) for whoever respecs next.
  Converted to container, claim released; draft patch + evidence note
  committed unpushed on branch `3IpBKtB8`.

## candidates

- gate `new`/`fsck` against a spec referencing paths absent from the
  item's resolved repo, and/or have `brief` mark a defaulted repo
  explicitly in its own output — stays here for triage: this is a
  `gitboard` tool change, needs the tool's own maintainer/refiner to
  scope it, not a same-pass fix.
