Six files on the `board` branch. Measured today; `flow.tl` is AT the
500-line cap and `action.tl` is 5 under, so both changes are net
deletions:

```
wc -l _work/{flow.tl,action.tl,gitreview.tl,gitverdict.tl,session.tl,flow_test.tl}
  500 flow.tl   495 action.tl   110 gitreview.tl
  250 gitverdict.tl   140 session.tl   220 flow_test.tl
```

**1. `_work/flow.tl` — delete `built_by` AND the `root` helper it
orphans.** `built_by` is the function (`:433-444`), its record field
(`:447`) and its export (`:477`). Nothing else in the module uses it.

`root` (`:406-419`, doc comment included) goes with it: it is a bare
local — not in the `record flow` field list, not in the returned table —
and its only callers are `:434`, `:435` and `:439`, all three inside
`built_by`. Leaving it behind fails the gate outright, measured:

```
_work/flow.tl:413:1: warning: unused function root: function(string): string
  hint: warnings are errors here — remove it, or prefix the name with `_`
```

The only apparent hit elsewhere is `_work/gitview.tl:205`, the literal
string `"%d organizing root(s)"` in a format call. `root_of`, `roots`
and `it.is_root` are unrelated and stay.

`root`'s doc comment is where the `/` wave-separator rule lives — an
orchestrator minting `<its own id>/<suffix>` counted as ONE session for
review distance. That rule dies with the machinery, and the audit
confirms nothing else needs it: its only other behavioural consumer is
`_work/action_test.tl`'s `test_review_skips_the_minting_orchestrator`
(Change 7), and the exact-string claim lock at `_work/gitverbs.tl:243`
never called `root` at all — it is deliberately unaffected, as the
completed item `3IVJVZJt` records, and must stay exactly as it is.

**2. `_work/action.tl` — remove the branch and the count it feeds.**
Delete the `built_by` test at `:194` so a `check` item is reviewable by
whoever asks. `ReviewPick.mine` then counts nothing: remove the field
(`:181-182`), its initialiser (`:192`), its increment (`:195`), the
mirror field at `:243`, the local at `:287` and the two constructor sites
(`:366`, `:369`). The terminal reason at `:430-437` currently reads
"nothing in check is this session's to judge (%d built by this session,
%d under another session's review)" — it keeps only the `reviewing` half,
so a full `check` with every item under another session's live review
still names why.

**3. `_work/gitreview.tl` — remove the claim-time refusal (`:59-66`)**,
the block whose comment reads "The same distance rule the verdict
enforces, moved to claim time". That call is the module's ONLY use of
`flow`, so `local flow = require("_work.flow")` (`:20`) goes with it or
the gate fails, measured:

```
_work/gitreview.tl:20:7: warning: unused variable flow: record flow
  hint: warnings are errors here
```

The rest of the verb — phase check, already-yours, the claim itself —
is unchanged.

**4. `_work/gitverdict.tl` — remove the verdict refusal (`:140-150`)**,
comment included. Every other refusal in the verb stays: wrong phase,
same-head, and the accept-time PR-state read.

**5. `_work/session.tl` — correct two doc comments.** `:6` says the
distance rests on distinct names and cites `built_by`. Distinct names
still matter for CLAIMS; the verdict half is gone. `:50` is the second:
"a human reviewing their own work is exactly what the distance forbids"
is the stated REASON the terminal identity is stable across days. The
reason changes — it is claim collision between two people on one host,
not review distance — while the behaviour it justifies does not.

**6. `_work/flow_test.tl` — delete `test_built_by_roots_names`
(`:199-220`, its leading comment included).** With `flow.built_by` gone
the test cannot compile, and there is nothing left in this module for it
to assert. The replacement reversal test does NOT belong here:
`flow_test.tl` requires only `_work.flow`, `_work.item` and
`_work.fixture` — it has no store, no repo and no `cmd_verdict` — so the
reversal is asserted in `_work/gitverdict_test.tl` instead (Change 7).
The measured compile failure this deletion answers:

```
_work/flow_test.tl:207:15: error: invalid key 'built_by' in record 'flow'
```

with the same error at `:208`, `:210`, `:212`, `:215`, `:217` and `:218`.

**7. The rest of the test suite — the measured blast radius.** Changes
1-6 name one test file. Four more assert the behaviour being removed, and
each aborts at its first failing assert, so the failures surface in
rounds rather than all at once. Measured 2026-08-29 by applying Changes
1-6 to the working tree and running `bin/cosmic --make test _work/` seven
times, neutralising what failed each round:

```
round 1 — test: FAIL (4 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:140: the session that built it is not
      handed the verdict: review
      in local 'test_a_session_is_not_handed_its_own_work_to_review'
  _work/converge_test.tl (exit 1):
      o/_work/converge_test.lua:337: seed 1: handed its own work to review
      in local 'test_no_walk_ever_names_a_move_the_gate_refuses'
  _work/gitreview_test.tl (exit 1):
      o/_work/gitreview_test.lua:70: no session reviews its own build
      in local 'test_the_builder_is_refused_the_claim'
  _work/gitverdict_test.tl (exit 1):
      o/_work/gitverdict_test.lua:105: the session that built it cannot
      accept it
      in local 'test_verdict_refuses_the_builder'

round 2 — test: FAIL (2 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:140: it pulls instead of stalling: review
      in local 'test_skipping_its_own_review_falls_through'
  _work/gitverdict_test.tl (exit 1):
      o/_work/gitverdict_test.lua:206: the first builder is refused on
      the diff they built
      in local 'test_verdict_refuses_a_past_builder'

round 3 — test: FAIL (1 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:191: the handover would be refused, so it
      is not offered: review
      in local 'test_a_full_check_of_its_own_is_not_a_finish_action'

round 4 — test: FAIL (1 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:194: refinement is still real work: review
      in local 'test_a_full_check_still_leaves_the_intake_half'

round 5 — test: FAIL (1 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:313: the session that built it is not
      offered the verdict: review
      in local 'test_reviewable_skips_a_past_builder'

round 6 — test: FAIL (1 of 29 files)
  _work/action_test.tl (exit 1):
      o/_work/action_test.lua:370: the orchestrator is not handed its
      wave's diff: review
      in local 'test_review_skips_the_minting_orchestrator'

round 7 — test: PASS (29 files)
```

Ten test functions across five files, plus one inner assertion. Every
failure message is the same fact: the answer that used to be withheld is
now `review`. That is the item's whole point, so INVERT wherever the test
still has something to say and delete only where the premise itself is
gone.

**`_work/action_test.tl`** — six affected, 26 test functions today, 25
after.

- `test_a_session_is_not_handed_its_own_work_to_review` (`:133`) →
  invert, rename to `test_a_session_is_handed_its_own_work_to_review`.
  `act.next_action(items, "session-A")` on the item A claimed now answers
  `review`. The session-B and unnamed-session probes below it already
  assert `review` and stand unchanged. DROP the
  `same.reason:find("built by this session")` assertion (`:141`) — Change
  2 deletes that reason text, and `:141` and `_work/action.tl:436` are
  its only two occurrences in the tree.
- `test_skipping_its_own_review_falls_through` → invert, rename to
  `test_its_own_review_outranks_a_pull`. Same board — own item in
  `check`, plus a `ready` item — and the answer flips from `pull` to
  `review`, which is the ordering's rightmost-phase-first rule now that
  nothing is skipped.
- `test_a_full_check_of_its_own_is_not_a_finish_action` → invert, rename
  to `test_a_full_check_of_its_own_is_now_a_review`. This is the
  Evidence section's deadlock, and its repair is the most valuable
  assertion in the item: a `check` full of the session's own work used to
  answer `none` with "nothing can be handed over until a verdict lands",
  and now answers `review` on the highest-placed of them — the verdict
  that drains the phase and releases the handover.
- `test_a_full_check_still_leaves_the_intake_half` → invert. The board
  keeps its `plan` item; the answer moves from `refine` to `review`. Its
  comment must move with it: a full `check` no longer strands the session
  because it falls through to the intake half, but because it can now
  judge what is in front of it.
- `test_reviewable_skips_a_past_builder` (`:305`) → invert, rename to
  `test_reviewable_offers_a_past_builder`. The 3I7LGcLa / PR #1301
  sequence — `claim = "session-B"`, `builders = "session-A session-B"` —
  now offers the review to A, B and C alike; flip the two `~= "review"`
  probes to `== "review"` and keep the C probe as is.
- `test_review_skips_the_minting_orchestrator` (`:362`) → DELETE. It is
  the last behavioural consumer of the `/` wave-separator rule Change 1
  removes, and nothing replaces it: `orch` and `orch/3IVKVslE` become two
  unrelated names to the review path. Delete its leading comment too.

**`_work/converge_test.tl`** — one inner assertion, 4 test functions
today and after. Keep `test_no_walk_ever_names_a_move_the_gate_refuses`
whole; delete only the four-line block at `:335-338`:

```teal
      if a.kind == "review" then
        assert(a.item.claim ~= session,
          ("seed %d: handed its own work to review"):format(seed))
      end
```

The surrounding property — every action the ordering names is one the
verbs carry out, and carrying it out moves the board — is untouched and
passed in all seven rounds. Three comments go stale and need correcting,
none of them assertions: `:322-325` ("a single name could never review
anything and the walk would never reach `land`" — after this change it
can, so the per-wake session is no longer load-bearing), `:387-391` and
`:444-446`. `test_a_solo_session_never_names_an_answer_it_cannot_act_on`
PASSED unchanged in every round; only its prose is wrong.

**`_work/gitreview_test.tl`** — one affected, 7 test functions today and
after. `test_the_builder_is_refused_the_claim` (`:65`) → invert, rename
to `test_the_builder_may_claim_the_review`: `rev.cmd_review(s, leaf,
"builder-a", false, "")` returns 0 and stamps `reviewer = "builder-a"`.
The takeover, `--force --why`, unnamed-session and wrong-phase tests
around it passed untouched in every round and are not to be changed.

**`_work/gitverdict_test.tl`** — two affected, 9 test functions today and
after.

- `test_verdict_refuses_the_builder` (`:97`) → invert, rename to
  `test_the_builder_may_verdict_its_own_item`. This is the reversal test
  Change 6 promised: `vrd.cmd_verdict(s, leaf, "accept", 11, "abc1234",
  "", "session-a")` returns 0 and the item moves `check -> land`. It
  belongs here because this file already has the store fixture the
  assertion needs.
- `test_verdict_refuses_a_past_builder` (`:190`) → invert, rename to
  `test_a_past_builder_may_verdict`. The rework-takeover sequence now
  lets `builder-one` accept. Note the ordering trap: once the first
  accept SUCCEEDS the item leaves `check`, so the inverted test asserts
  one accept lands and drops the "and the standing rework verdict is
  untouched by the refusals" assertion, which only held while both were
  refused.

**Untouched, and confirmed so by measurement.** `action_pick_test.tl`,
`gitverbs_test.tl`, `gitclaim_test.tl`, `gittake_test.tl`,
`session_test.tl` and the other 19 test files passed in every round
including round 1. The coverage ratchet also passed after the change
(`coverage ratchet ok`, `coverage: PASS (29 files)`), so no floor rewrite
is needed.

**KEEP `builders`.** It stays written, read by `show`, and described as
the audit record of who held the claim. `3IY2Bj90` wants more recording,
not less, and the review subagent's own derived identity on the verdict
is what makes isolation auditable.
