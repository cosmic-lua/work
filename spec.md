# friction: 2026-09-06 work5-routine (/work 5 --routine)

## orchestrator
- goal: pull the highest-ranked pullable todo item (`next`'s top pick, «LVYj_DA0K»).
  actually happened: `next` ranked «LVYj_DA0K» first as "passing the spec bar" even
  though its own `## Change` opens with "Once «RNb7_b0tV» lands ... resume from
  branch 3Iw4Klc9" — «RNb7_b0tV» was still an unclaimed todo item at the time, so
  «LVYj_DA0K» could not actually be built yet. Caught by reading the spec before
  taking (1 extra `show` call) rather than taking-then-dropping; pulled
  «RNb7_b0tV» itself instead, which is the real unblocking work.
  contributed: `next`'s `[pullable]` marking checks spec-section structure, not a
  spec's own "Ready when: ..." precondition or a prose cross-item dependency that
  never got written as one. This is the SAME gap `907S_v021`'s friction log
  already logged three occurrences of last pass (`rhKJ_HSQd`, `8TDI_yqOV`,
  `rLV8_r8a5`) and left in its `## candidates` as "stays here for triage: no
  concrete `## Change` written... a refiner should size it as its own item" —
  this is a 4th occurrence, not a new finding.
  improvement: don't re-file a duplicate candidate; `find "next repeatedly
  surfaced"` surfaces `907S_v021` for whoever next sizes this into two items
  ("Ready when" parsing, stale-premise detection) as it already proposes. Noting
  the 4th hit here so the recurrence count is visible without re-deriving it.
- goal: claim a fresh todo item («RNb7_b0tV») and hand it to a builder subagent
  under the orchestrate-minted label `build-RNb7_b0tV-39b93fa3`.
  actually happened: `take RNb7_b0tV` (no `--session`) claimed it under my raw
  session id instead; `brief builder RNb7_b0tV` then named the minted label as
  the one to claim under, so a second `take --session build-RNb7_b0tV-39b93fa3
  --force --why ...` was needed to match. 2 `take` calls where 1 would do. Same
  shape recurred for the review claim (`70P4_YBPd`): reclaimed once under my raw
  session id, then again under `review-70P4_YBPd-39b93fa3` once `brief` named it.
  contributed: the minted label is fully derivable before the first `take`
  (`<kind>-<handle>-<orch8>`, `orch8` from my own `show`'s session line) — nothing
  about it depends on `brief`'s output.
  improvement: `orchestrate`'s help topic could say to mint and pass `--session`
  on the FIRST `take` for a to-be-spawned item, rather than reading the label
  off `brief` after the fact. A doc-level fix (the `orchestrate` help topic),
  not a gate.
- goal: get a builder-ready brief for «RNb7_b0tV» to spawn the subagent.
  actually happened: `bin/gitboard show RNb7_b0tV` showed no `repo:` line at
  all, and the first `brief builder RNb7_b0tV` opened with "You are a builder
  agent for `cosmic-lua/work`" — the board's OWN repo — even though the item's
  title and Change are entirely about `_types/gentype_parse.tl`, a
  cosmic-lua/cosmic path. Caught before spawning by reading the brief text
  rather than pasting it straight through; `gitboard set RNb7_b0tV --repo
  cosmic-lua/cosmic` fixed it and the brief regenerated correctly. Two other
  doing items («70P4_YBPd», «0oBN_Fa6X») show a `set ... repo` commit in their
  own history, so this is not a one-off — it recurs for items filed as
  evidence findings mid-build (`new --parent <ID>`), which land with no
  `repo:` set.
  contributed: `new` has no required/inferred `repo` at creation, and `brief`
  silently falls back to the board's own repo (cosmic-lua/work) rather than
  refusing or flagging the gap — a wrong-repo PR is a much more expensive
  mistake to unwind than a refusal here would be.
  improvement (gate, ranks above a doc): `brief builder/review ID` should
  refuse (not silently default) when an item has no `repo:` set, naming the
  fix (`gitboard set ID --repo OWNER/NAME`). Filed as `MD7t_OaND` under
  `mHDU_d37y` (cosmic-lua/work) — same "wrong repo" theme that container's
  own title already names, with the exact root cause pinned to
  `_work/brief.tl:301`'s `gh.slug(s, it.repo)` (correct for the board's-own
  gates, wrong here — should default to `product.REPO` instead). Hit a
  THIRD time in this same pass while triaging `gVi7_9Ne8` (also filed with
  no `repo:`, also defaulted to `cosmic-lua/work`) — repaired the same way
  before spawning its builder.
- goal: reclaim the two stale `doing` claims left from the prior orchestrator
  wave (`70P4_YBPd` review, `0oBN_Fa6X` build) before starting a new one.
  actually happened: `take 70P4_YBPd` succeeded immediately (stale claim, no
  `--force` needed); `take 0oBN_Fa6X` was correctly REFUSED ("claimed by
  build-0oBN_Fa6X-fe8c92c8 — take over a live claim with --force"), confirming
  it is still genuinely running elsewhere — left it, per doctrine. No friction;
  noting it because the two claims looked identically old from `show`'s output
  alone (both from session suffix `fe8c92c8`, claimed hours apart) and only
  `take`'s own live/stale determination actually distinguished them — reading
  wall-clock age alone would have been the wrong signal either way (one call
  guessed right by luck, the other would have guessed wrong).
- two board-graph items surfaced as `role: outcome` under the board root with
  no rank («gVi7_9Ne8», «WK7p_Gljy») — real, well-scoped bug/process items,
  just never attached under an actual G-outcome after being filed unparented.
  Attached under best-fit siblings (`5bUQ_BTyj`/G3 for the type-narrowing bug
  next to `vmX5_zQH2`; `J9an_mT6e`/G5 for the gotchas-ratchet process item
  next to `wZmq_duSZ`) and ranked last. Not friction — routine triage — noting
  only because `attach ID PARENT --after X` refused with "no item matches tail"
  for handles copy-quoted straight from `show`'s own output (guillemets and
  all); the ID PREFIX form (`3Iwc5469`) worked immediately. Possibly a
  rendering/encoding quirk in how the handle's divider character round-trips
  through a terminal copy — not chased further this pass; prefixes are the
  reliable form.

## build RNb7_b0tV (Sonnet 5) — PR #1745, 371s, 39 tool calls
- transcript: events=157 tool_calls=39 wall=371s; tokens in=80 out=1500
  cache_read=2844874 cache_create=70463; by tool: Bash=25 Edit=3 Read=9
  ToolSearch=1 mcp__github__create_pull_request=1; first edit at call 12;
  0 errors; 4 files re-read repeatedly while tracing the fix (5x/3x/2x/2x)
  but nothing thrown away.
- goal/actually happened/contributed/improvement: none — the agent's own
  `## Friction` section reported "None worth logging... no rediscovery,
  no wrong turns, no thrown-away work," and the transcript numbers back
  it: 0 errors, first edit at call 12 of 39, no wasted diff.
- fixed `_types/gentype_parse.tl`'s `TYPE_TAG` regex (capture was
  `[%w_%.]+`, truncating `table<string, integer>` to `table`) to route
  the full annotation through the existing `scan_token`/`convert_type`
  path already used for `@param`/`@return`. Added
  `test_generic_type_field_round_trips`; mutation-tested by reverting
  the regex (new test failed as expected) and restoring it (16/16 pass).
  `bin/cosmic --make ci` green, 5 stages, 3342 tests. Recorded on the
  board as `RNb7_b0tV`'s PR handover (`take ... --pr 1745`); awaiting
  review next pass.

## review 70P4_YBPd (Sonnet 5) — request-changes, 400s, 45 tool calls
- transcript: events=177 tool_calls=45 wall=400s; tokens in=88 out=650
  cache_read=3071596 cache_create=89740; by tool: Bash=35 Edit=1 Read=3
  ToolSearch=1 mcp__github__add_issue_comment=1 mcp__github__pull_request_read=4;
  first edit at call 24; 1 error, repeated 2x (see below).
- goal: record the verdict with `bin/gitboard verdict ... --session
  review-70P4_YBPd-39b93fa3` right after `sync` reported "state is current".
  actually happened: the first `verdict` call failed — `no item matches
  3ItZVev6Kfkjrtu0FqD70P4YBPd` (exit 1) — even though `sync` had just run;
  an immediate `show` on the same id succeeded, and a verbatim retry of
  `verdict` then succeeded too. ~3 extra tool calls and, per the agent's
  own account, "a few minutes of doubt about whether the id or session
  string was wrong."
  contributed: unclear from the transcript alone — reads as a transient
  staleness in the sibling `GITBOARD_DIR` clone (this pass's orchestrator
  and the review agent share `/home/user/work` as `GITBOARD_DIR`, so a
  `sync` racing a concurrent read is plausible) rather than anything wrong
  with the command itself.
  improvement: if this is a known transient in the shared-clone shape,
  `gitboard help verdict`/the `work` skill could say "retry once on 'no
  item matches' right after a sync" so an agent doesn't spend a detour
  doubting its own id/session string. Not sized enough here to file as
  its own item — one occurrence, no root cause confirmed.
- the review itself found a real gap CI couldn't catch: PR #1744 removed
  the stale "keep the binary outside the project" caution from
  `docs/guides/quickstart.md` but left the more authoritative
  `docs/guides/lint.md:26-28` (served by `cosmic --docs guide.lint`)
  making the same now-false claim about binaries. Quoted with file:line
  in the PR comment; verdict `request-changes`, mutation test on the
  `is_binary` guard confirmed real (flipped to `false`, the diff's own
  test failed as expected; restored, byte-identical, full `--make ci`
  green again).

## candidates
- `brief builder/review ID` should refuse when an item has no `repo:` set
  instead of silently defaulting to cosmic-lua/work — filed as `MD7t_OaND`
  under `mHDU_d37y` (cosmic-lua/work).
- `next`'s `[pullable]` marking doesn't check a spec's own "Ready when: ..."
  precondition or a prose cross-item dependency — 4th occurrence now
  (`rhKJ_HSQd`, `8TDI_yqOV`, `rLV8_r8a5` per `907S_v021`; `LVYj_DA0K` here).
  Stays in `907S_v021`'s own candidates list for triage — not re-filed, to
  avoid a duplicate of an already-tracked, not-yet-sized item.
- `gitboard verdict` returning "no item matches <full id>" immediately after
  a `sync` reported current, self-resolving on retry — stays here for
  triage: one occurrence, root cause unconfirmed (see review agent's entry
  above).

## review RNb7_b0tV (Sonnet 5) — accept, 233s, 37 tool calls
- transcript: events=142 tool_calls=37 wall=233s; tokens in=70 out=942
  cache_read=2634363 cache_create=65450; by tool: Bash=22 Edit=2 Grep=3
  Read=4 ToolSearch=2 mcp__github__enable_pr_auto_merge=1
  mcp__github__pull_request_read=3; first edit at call 16; 1 error
  (a `grep`/`xargs grep -ln` combo exited 123 — no matches, non-fatal,
  self-recovered next call); 2 commands repeated (re-reading the
  parser file 5x while tracing the fix, rerunning the gentype test 2x
  around the mutation).
- goal/actually happened/contributed/improvement: none — the agent's
  own `## Friction` section reported "Nothing to report... went through
  cleanly on the first pass," and the transcript backs it (1 non-fatal
  error, no dead ends, first edit at call 16 of 37).
- verdict `accept`, auto-merge (squash) enabled via
  `mcp__github__enable_pr_auto_merge`; PR #1745 subsequently entered
  the merge queue (GitHub notification, 11:09 UTC). CI green on all 5
  lanes at head `9666c283`; mutation test on the `TYPE_TAG`
  regex/`scan_token` extraction confirmed real (reverted, the diff's
  own new test failed exactly as expected; restored, 16/16 green).

## build gVi7_9Ne8 (Sonnet 5) — stopped short, 424s, 39 tool calls
- transcript: events=157 tool_calls=39 wall=424s; tokens in=80 out=426
  cache_read=2642728 cache_create=72599; by tool: Bash=33 Edit=1 Read=5;
  first edit at call 35 (a scratch probe file, reverted — the real
  file was never edited, per stop-short instructions); 3 errors, all
  expected type-checker output from the agent's own probes, not
  mistakes; `cosmic/net/init.tl` and `cosmic/tty.tl` each read 2x
  (comparing the spec's cited pattern against the actual file).
- goal: implement the spec's literal `fd2 is string` narrowing branch
  in `cosmic/net/init.tl`, mirroring `cosmic/tty.tl`'s `openpty`.
  actually happened: does not type-check — this worktree's pinned
  cosmos release (`3p/cosmos/cosmos_pin.tl`: `2026.09.04-65bc139fc`)
  still generates `socketpair`'s OLD, 4-slot, factually-stale signature
  (`fd2: integer`, not `integer | string`); `./o/bin/cosmic --check
  types cosmic/net/init.tl` refuses with "fd2 (of type integer) can
  never be a string." Confirmed via a fresh build (not a cache
  artifact) and cross-checked the corrected annotation exists in the
  sibling cosmopolitan checkout's `definitions.lua` but no cosmos
  release carrying it is pinned here yet. Stopped per brief instructions
  rather than casting past the checker; left the probe-only diff
  committed, unpushed, on branch `3Iwc5469` at `886cd4d`.
  contributed: the item's own Evidence section already flagged the
  risk ("verify against the pin's embedded cosmo/unix.d.tl once
  picked up... do not assume the exact shape from this item's Evidence
  alone") but the item was refined/ranked pullable before that
  verification step was actually run against a current pin — same
  STALE-PREMISE shape `907S_v021`'s friction log already named as a
  `next`-readiness gap (see the orchestrator's first entry above).
  improvement: filed the gap as a child item
  (`2cBg_AIxm`/`3Ix5CMGS`, "bump `3p/cosmos/cosmos_pin.tl` to a
  release carrying unix.socketpair's corrected fd2 annotation") under
  `gVi7_9Ne8` per `help build`'s "file the question as a CHILD, then
  drop" rule; filing the child auto-converted the item to a container
  and released its claim with no separate `drop` call needed (a bare
  `drop --session ...` afterward correctly refused: "not in flight —
  nothing to drop").
