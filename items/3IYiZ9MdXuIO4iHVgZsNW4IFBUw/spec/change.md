**1. `skills/work/review.md` — replace the `never your own` paragraph
(`:11-16`) with the isolation rule.** State: the review runs in a
subagent with a fresh context, spawned for that one item; the brief
carries the item id, the PR number and the six checks, and NOT the
orchestrator's reasoning about the item; the subagent reads the spec and
the diff from the board and GitHub itself. State the reason in one line —
a fresh window cannot be biased by context it does not hold. Keep the
existing sentence that `check` is the only phase a verdict may end.

Add to the same section: the subagent runs `gitboard verdict` ITSELF, so
the identity the board records is the reviewer's own, not the
orchestrator's. That is the audit trail — the log then shows whether
reviews were run in isolation, which no gate can verify.

**2. `skills/work/review.md` — strengthen the adversarial posture.** The
six numbered checks stay as they are. Add, in the `## the review itself`
preamble, that the reviewer's job is to try to make the diff fail: run
the acceptance commands rather than reading them, and mutation-test at
least one guard the change adds — break it, watch the test go red,
restore it. A gate that cannot be shown to fail is decoration.

**3. `skills/work/parallel.md` — split the `what never fans out` clause
(`:175-177`).** Keep "N agents reviewing N PRs in parallel" forbidden,
with its existing reasoning. Add that ONE review in ONE isolated subagent
is required, not forbidden, and that the distinction is throughput versus
context — the rule was never about where the review runs.

**4. `skills/work/loop.md` — rewrite step 3 (`:32-33`).** "inline, in
this session, never fanned out" becomes: spawn one review subagent, wait
for it, act on its verdict. One item per pass stays.

**5. `skills/work/SKILL.md` — the hard rule at `:435` and the
session-identity paragraph.** The rule "no session accepts its own work"
keeps its name and loses its mechanism sentence ("the derived session
identity enforces it in `next`"): it is now carried by the review
procedure, and `SKILL.md` says which. The session-identity paragraph
keeps everything it says about unique names for CLAIMS — that half is
unaffected — and drops the clause about withholding a verdict.

**6. `skills/work/review.md` and `skills/work/SKILL.md` — the review
subagent NAMES ITSELF.** State in `review.md`, where the subagent is
established, that it exports `GITBOARD_SESSION` set to a value unique to
that review before running `gitboard verdict`, and why: a subagent
inherits the session id of the process that spawned it, so an unnamed
reviewer resolves to the BUILDER's identity — and `built_by` reads the
claim AND the `builders` list, so `review` and `verdict` both REFUSE.
An unnamed reviewer cannot record a verdict at all. Naming itself is
what makes the review recordable, and what makes the log name the
reviewer rather than the builder. Do NOT write that the board records an
unnamed reviewer's verdict under the builder: while `built_by` is live
it records nothing. The refusals are `_work/gitreview.tl:62` and
`_work/gitverdict.tl:145`, both on `flow.built_by`. Measured
2026-08-28 on a synthetic board (`gitboard --dir`) whose item sits in
`check` under the claim `builder-demo`:

```
$ GITBOARD_SESSION=builder-demo gitboard review 3IZ1M9Kc
REFUSED: 3IZ1M9Kc is builder-demo's own build — no session reviews
its own work

$ GITBOARD_SESSION=builder-demo gitboard verdict 3IZ1M9Kc \
    'request changes' --enable 'none: demo'
REFUSED: 3IZ1M9Kc is builder-demo's own build — the claim or builders
record names them, and no session accepts its own work

$ GITBOARD_SESSION=review-demo-1 gitboard verdict 3IZ1M9Kc \
    'request changes' --enable 'none: demo'
request changes on 3IZ1M9Kc: check -> do
  … verdict 3IZ1M9Kc request changes (check -> do) by review-demo-1
```

`SKILL.md`'s session-identity paragraph carries the matching carve-out,
or it contradicts this: a review subagent is the case where the derived
value is WRONG rather than absent, so it names itself, and that is not
the inline invention the paragraph warns against. What that paragraph
says about CLAIMS stays as it is. `loop.md` takes the same one-clause
correction wherever it states the audit-trail promise: the verdict's
identity is exported, not derived, and an unnamed one is refused.

**7. `skills/work/loop.md` — rewrite the `## minted identities and the
verdict wall` section.** The wall goes and isolation carries the whole
distance: a subagent whose window never held the build is disinterested
however it was spawned, so nothing is left for the wall to add. Rename
the heading to the subject the section now has — the orchestrator's own
wave — and keep the minted-claim paragraph exactly as it is (unique
suffixes so claims lock, the orchestrator prefix so provenance stays
readable in the log). The wall's paragraphs are replaced by four
statements:

- **the rule.** An orchestrator may take the verdict on its own wave.
  The review runs in a subagent whose window never held the build —
  not the brief that spawned the builder, not the agent's report, not
  the pass's reasoning about the item — so this is `review.md`'s rule
  reaching the case a loop meets every pass, not an exception carved
  out of it.
- **the brief.** The distance is only as good as the brief: it carries
  the item id, the PR number and the checks, and NOT the session's own
  reading of the item, because a brief that summarises what the wave
  was trying to achieve hands the reviewer back the commitment a fresh
  window exists to be without.
- **the audit record.** The claim and `builders` say who held the item
  and who built it; the verdict carries the review subagent's own
  exported name. This is Change 6's audit-trail correction, landing
  inside the rewritten section rather than beside it.
- **what `next` does with it.** `next` does not offer an item whose
  claim or `builders` name this session — names compare by the claim's
  prefix, so work a minted agent built reads as the orchestrator's own
  — and it steps over such an item silently. So the review subagent
  is spawned on the item id directly, the one step 1 reconciled into
  `check`, rather than waited for. Step 3 names the same id source and
  the `never blocked` table gains the row. Say nothing about when the
  stepped-over count surfaces: both `none` returns under `if ph.mine >
  0 or ph.reviewing > 0` in `_work/action.tl` carry that count, and the
  WIP limit only selects which sentence carries it. Measured by calling
  `action.next_action` with `check` below its limit and at it:

  ```
  check at 1/10  → nothing in check is this session's to judge
                   (1 built by this session, 0 under another session's
                   review) — their verdicts land elsewhere
  check at 10/10 → check is at 10/10 with nothing this session may
                   judge (10 built by this session, 0 …) — nothing can
                   be handed over until a verdict lands
  ```

Write all four as properties of the tool in the skill's own voice: no
history, no item references, no interim framing.

**8. `skills/work/parallel.md` — the `do not merge` bullet's landing
clause.** "a PR lands only after an accept, in a later pass by a
session that did not build it" asserts the identity doctrine this item
retires, and it contradicts the loop's own landing step, which lands a
wave's accepted PRs on the next pass of the session that spawned the
wave. Correct that one clause. What the bullet tells the AGENT is
unchanged: it does not merge, and its loop ends at the opened PR.
