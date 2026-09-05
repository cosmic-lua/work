# friction: 2026-09-05 w9 (/work 9 --routine)

## orchestrator
- goal: pull one action from `gitboard next` using a sibling `cosmic-lua/work`
  checkout instead of `o/board` (this session already had one at
  `/home/user/work`, per the bootstrap's own "check for one before cloning a
  second copy" step).
  actually happened: `gitboard brief refine <ID>` filled `<PRODUCT_ROOT>` as
  bare `cd /home` instead of `cd /home/user/cosmic`, because
  `GITBOARD_DIR=/home/user/work` doesn't end in `/o/board` and the brief's
  PRODUCT_ROOT derivation strips that suffix assuming the clone always lives
  there (confirmed against `_work/brief_test.tl:339-345`, which only tests
  the `.../o/board` shape). Cost: one extra read of `brief_test.tl` plus a
  hand-corrected `cd` line in the brief before spawning (~3 tool calls, no
  wasted agent work since caught before spawn).
  contributed: `_work/brieftext.tl`'s PRODUCT_ROOT fill assumes
  `$GITBOARD_DIR` is always `<product-root>/o/board`, which is false exactly
  when a session reuses a sibling `work` checkout per the skill's own
  documented shortcut (`skills/work/SKILL.md`'s bootstrap block).
  improvement: derive PRODUCT_ROOT from the product checkout's own cwd (where
  `bin/gitboard` was invoked from) rather than by string-stripping
  `$GITBOARD_DIR`, so the sibling-checkout shortcut and the `o/board` clone
  path both fill correctly. Gate-level fix in `_work/brieftext.tl`; passes
  the spec bar (concrete file/behavior, no design question). Not filed this
  pass — one bug on one field of one brief kind is below the line for an
  unparented triage item on its own; noted here for the next friction log to
  compare against if it recurs.
- goal: also unrelated — `gitboard next` initially returned a triage action
  (an unranked outcome `HlZW_zWbs` blocking ALL 191 todo items from being
  pullable: `show` reported "todo 191 (0 pullable)").
  actually happened: resolved by `gitboard rank HlZW_zWbs --last` per `next`'s
  own suggested fallback ("No outcome fits? Rank it last regardless") — no
  goal-owner comparison needed, so this stayed inside --routine's
  no-questions rule. One command, no cost beyond confirming the doctrine
  text permitted it.
  contributed: n/a — the tool named the exact fallback command.
  improvement: none needed; this is the system working as documented.

## refine sTmy_8tBZ (general-purpose) — landed, 492s, 21 tool calls, ~2.1M tokens (cache-read-heavy: in=40 out=564 cache_read=1922884 cache_create=140991)
- goal: rewrite the item's spec to carry a concrete `## Change`, grounded
  in measured facts rather than inference, per the brief and `gitboard help
  bar`.
  actually happened: succeeded on the first `gitboard spec` write (no CAS
  conflict), first edit at call 18 of 21 — most of the run (calls 1-17) was
  reading `test_definitions_coverage.lua` (1517 lines) and
  `test_definitions_conformance.lua`, grepping the sibling cosmopolitan
  checkout for the two named bindings, and a Python scan of `lunix.c` for
  other bindings sharing the vulnerable shape. `_tool/friction.tl` flags 3
  repeated commands (re-reading the same two files, re-`cd`-ing into
  `/home/user/cosmopolitan` twice) — plausible re-orientation after the
  Python scan rather than a wrong turn.
  contributed: the corrected brief (PRODUCT_ROOT and the read-only
  cosmopolitan-sibling pointer, both hand-filled by the orchestrator this
  pass) gave the agent everything it needed with no back-and-forth; its own
  friction section reports none.
  improvement: none indicated — this is what a well-formed brief looks
  like landing cleanly.

## decompose 0isr_qZds (general-purpose) — landed (2 children filed + outcome spec corrected), 863s, 68 tool calls, ~7.75M tokens (in=138 out=1184 cache_read=7606951 cache_create=145183)
- goal: cut the "C line coverage" outcome into a research spike plus
  follow-on build item(s), per the brief's literal framing.
  actually happened: the agent first ran `gitboard find "gcov"` (not
  instructed to, on its own judgment) and discovered the brief's premise
  was stale — a research item and three build items under this exact
  outcome were already `done`, closing the feasibility question the brief
  told it to spike. It filed only the two build items the outcome's own
  spec still literally asked for (CI wiring + the line-coverage floor
  itself), corrected the outcome's own spec text, and reported this
  explicitly rather than duplicating closed work.
  contributed: the outcome's own spec was never refreshed when its last
  tracked child closed, so the text the brief quoted verbatim ("no
  `-fprofile-arcs`/gcov appears anywhere") was false by the time this pass
  read it — nothing enforces that a container's summary prose stays
  current once its children land.
  improvement: a step in `gitboard help review` (or wherever "verify the
  outcome's win condition still holds" already lives) that also refreshes
  the container's own stale Problem/Evidence text when its last known
  child closes. Not fully spec'd this pass — doing so needs reading the
  work repo's own review/decompose help text to cite the exact line, which
  this pass's budget didn't reach; left as a triage candidate rather than
  filed half-measured.
- goal: measure gcov's `--json-format` output-naming convention before
  writing it into a spec as fact (nothing in the tree or prior items had
  measured it), reproducing it against a throwaway host-gcc/gcov file in
  a scratch subdirectory under the session scratchpad.
  actually happened (from the transcript, not the agent's own account —
  its self-reported friction did not mention this): of the run's 68 tool
  calls, 44 were `cd <scratchpad>/gcovtest`-prefixed Bash calls that
  exited 1, one surfacing `pwd: error retrieving current directory:
  getcwd: cannot access parent directories: No such file or directory` —
  i.e. roughly two-thirds of this agent's tool calls were spent against a
  scratch directory that had become unreachable partway through, each
  presumably re-attempted with a fresh `cd` per the harness's per-call
  shell semantics. The agent still finished with a correct, cross-checked
  reproduction (its "Change" section's gcov output table matches a
  manual redo), so the work was not lost, but the wall-clock cost is
  concrete: at ~13s/call average across the run, 44 failed calls is a
  meaningful fraction of this agent's 863s.
  contributed: unclear from the transcript alone whether the directory
  was deleted by something else, or a sandbox boundary made it
  intermittently unreachable — this reads as environment/sandbox
  behavior for throwaway scratch subdirectories, not a bug in the
  brief, the spec, or gitboard/cosmic doctrine.
  improvement: none filed — this is outside the board's and the
  product's scope (an orchestration-sandbox property, not a repo or tool
  defect); flagged here so a repeat in a future pass's friction log can
  confirm whether it recurs before anyone spends a fix on it.
- goal: file the outcome's second child ranked after the first
  (`gitboard new ... --after <first-child>`).
  actually happened: refused once ("X is unpositioned among its siblings
  — rank it first, or use --last") until the agent ran `gitboard rank
  <first-child> --last` and retried `new --after`, which then succeeded —
  one extra command, matching the tool's own documented behavior.
  contributed: `_work/gitrank.tl:51-57`'s own doc comment states this is
  deliberate ("a caller who wants ID last says so with `--last`" —
  refusing rather than silently auto-appending X first), so this is the
  tool working as designed, not a gap.
  improvement: none — checked the source before proposing anything: the
  agent's own suggestion ("`new --after` could auto-rank-last an
  unpositioned X itself") would reverse a documented, intentional
  refusal, so it does not pass the bar as a fix; noted only so a second
  occurrence doesn't get proposed again without checking `gitrank.tl`
  first.

## countermeasures filed this pass
- «A5NT_ilwk» cosmopolitan: cross-reference lfuncs.o vs lfuncs3.o's
  MODE=cov split in both BUILD.mk comments — the decompose agent's own
  Evidence section for `W3uo_Bvcn` had to re-derive, from three
  `BUILD.mk` files, which of two objects compiling the same source
  actually carries test coverage; `tool/net/BUILD.mk:126-127` names the
  split one-way but `tool/lua/BUILD.mk`'s `TOOL_LUA_LUA_MODULES` names it
  nowhere. Filed under the same outcome (`0isr_qZds`), spec measured
  directly against both files plus `tool/lua/lfuncs3.c`'s two-line body.

## candidates
- PRODUCT_ROOT-from-GITBOARD_DIR string-stripping in `_work/brieftext.tl`
  breaks for the sibling-checkout shortcut the bootstrap itself recommends —
  stays here for triage: a single-field bug in one brief kind, seen once,
  doesn't yet meet "the same wrong turn seen twice."
- a review/decompose-time step that refreshes a container outcome's own
  stale Problem/Evidence prose when its last tracked child closes — stays
  here for triage: needs a citation into the work repo's own help text
  this pass didn't reach.
