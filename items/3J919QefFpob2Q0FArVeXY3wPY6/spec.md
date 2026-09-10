## Evidence

`gitboard help orchestrate` and every `brief KIND ID` verdict line
("claim it as `build-<handle>-<orch8>`") read as though that printed
label is the value `claim --session` expects. It is not: `claim`,
`renew`, `drop`, `take`, `verdict` and `done` all refuse anything but a
32-hex id minted by `gitboard session new`.

```
$ bin/gitboard claim 3J919QefFpob2Q0FArVeXY3wPY6 --session refine-eXY3_wPY6-ff5e70a9
gitboard-claim: a claim needs a minted 32-hex session id — run `gitboard session new` and pass --session or set GITBOARD_SESSION
$ bin/gitboard done 3J919QefFpob2Q0FArVeXY3wPY6 --session refine-eXY3_wPY6-ff5e70a9
gitboard-done: REFUSED: a claim needs a minted 32-hex session id — run `gitboard session new` and pass --session or set GITBOARD_SESSION
$ bin/gitboard drop 3J919QefFpob2Q0FArVeXY3wPY6 --session refine-eXY3_wPY6-ff5e70a9 --why probe
gitboard-drop: a claim needs a minted 32-hex session id — run `gitboard session new` and pass --session or set GITBOARD_SESSION
$ bin/gitboard take 3J919QefFpob2Q0FArVeXY3wPY6 --session refine-eXY3_wPY6-ff5e70a9 --head HEAD
gitboard-take: REFUSED: a claim needs a minted 32-hex session id — run `gitboard session new` and pass --session or set GITBOARD_SESSION
$ bin/gitboard verdict 3J919QefFpob2Q0FArVeXY3wPY6 accept --session review-eXY3_wPY6-ff5e70a9
gitboard-verdict: REFUSED: a claim needs a minted 32-hex session id — run `gitboard session new` and pass --session or set GITBOARD_SESSION
```

The original write-up also named `worktree` among the refusers. Measured,
it is not one — `worktree` resolves its session through `_work/session.tl`
(the environment ladder), which never refuses, and fails on the
claim-holder comparison instead:

```
$ bin/gitboard worktree 3J919QefFpob2Q0FArVeXY3wPY6 --session refine-eXY3_wPY6-ff5e70a9
gitboard-worktree: REFUSED: eXY3wPY6 is not claimed by refine-eXY3_wPY6-ff5e70a9 — claim it first
```

The label is not merely advertised in prose: a review brief pastes it
into three `gitboard verdict` command lines it hands the agent, so a
reviewer that follows its brief verbatim always hits the refusal above.

```
$ bin/gitboard brief review oWct_h9xv | grep -n "REVIEW_SESSION\|--session"
332:those operations. This review is claimed under session `review-oWct_h9xv-ff5e70a9-2` —
340:  --head d71619314d44687993eb057005f6a2397f59bb7b --session review-oWct_h9xv-ff5e70a9-2 --repo-dir /home/user/wt/review-3J7MKAsx
342:  --head d71619314d44687993eb057005f6a2397f59bb7b --session review-oWct_h9xv-ff5e70a9-2 --repo-dir /home/user/wt/review-3J7MKAsx
344:  --head d71619314d44687993eb057005f6a2397f59bb7b --session review-oWct_h9xv-ff5e70a9-2 --repo-dir /home/user/wt/review-3J7MKAsx
368:gitboard-brief: review brief for «oWct_h9xv», claim it as review-oWct_h9xv-ff5e70a9-2 — nothing left to fill — paste the body verbatim
```

Which side is the newer design is settled by history: the readable
label predates the 32-hex claim identity, and was never revisited when
it landed.

```
$ git log -1 --format='%ad %h %s' --date=short -- _work/session.tl
2026-09-06 76b510bf gitboard worktree ID: one command for a builder's checkout (#58)
$ git log -1 --format='%ad %h %s' --date=short -- _work/claimsession.tl
2026-09-08 ae840934 Redesign gitboard around caller-owned Git transport (#90)
```

Cost on 2026-09-10: one failed `claim` call per item across a 5-item
build wave, plus the investigation to notice the mismatch.

## Change

One mechanism: **a brief names the session the item is actually claimed
under, and never mints a claim string of its own.** `gitboard session new`
stays the only way a claim identity comes into existence.

`_work/brief.tl` (472 lines; `wc -l _work/brief.tl` → `472`, so 28 lines
of headroom under the 500-line cap — this change is net-negative there):

- Replace the label selection. Today (`grep -n "label = " _work/brief.tl`):

  ```
  342:  local label = ""
  344:    label = prep.session
  346:    local review_label, err = brief_label.review(s, it.id)
  350:    label = review_label
  352:    label = mint_label(kind, tail.bare(it.id))
  ```

  becomes: `label = prep.session` when a preparation receipt supplied one
  (unchanged first branch), otherwise `label = it.claim or ""`. Delete the
  `kind == "review"` branch and the `mint_label` fallback outright.
- Drop `local brief_label = require("_work.brief_label")` (line 25) and
  `local mint_label = brief_label.mint_label` (line 51), and remove
  `mint_label` from the module's exported record (lines 460 and 468) —
  it is re-exported from `brief.tl` today and has no caller outside the
  brief modules (`grep -rn "brief_label\|mint_label" _work/*.tl`).
- Refuse a review brief that has no session to name, before any body is
  emitted, with `gate.verdict_line("brief", false, ...)` in the same shape
  as the neighbouring refusals at lines 322-333. Two cases, two messages:
  - `it.claim` empty:
    `"%s carries no active claim — a review records its verdict under the claim it is spawned from; claim it with a session from `gitboard session new`, then re-run this brief"` with `id:sub(1, 8)`.
  - `it.claim` non-empty but `gate.distance_refusal(it, it.claim) ~= nil`
    (`_work/gitgate.tl:170`, already used by `_work/gitverdict.tl:50` and
    `_work/gittake.tl:104`): return that refusal string as-is, prefixed by
    `("%s is still claimed by the session that built it — "):format(id:sub(1, 8))`.
    Without this, a review brief emitted before the orchestrator re-claims
    hands the reviewer the builder's own session, which `verdict` then
    refuses at the far end of the agent's run.
- Rewrite the two verdict lines (lines 441 and 454) and the
  `session_phrase` that feeds them (line 424,
  `local session_phrase = prep.session ~= nil and "prepared session" or "claim it as"`).
  There is no longer a "claim it as" case: when `label ~= ""` the phrase is
  `"prepared session"` for the receipt path and `"claimed under session"`
  otherwise. When `label == ""` (a non-review brief for an unclaimed item —
  the ordinary case, since the caller may emit a refine or decompose brief
  before claiming) the verdict line carries no session clause at all and
  instead ends with
  `"— mint a session with `gitboard session new` and claim it before spawning"`
  ahead of the existing `tail_note`.
- Update the module doc comment at lines 13-17, which currently says every
  brief "mints and fills the session label this kind's own claim belongs
  under (`mint_label`) ... so the orchestrator claims — `take ID --session
  <label>` — under the exact string the brief just printed".

Delete `_work/brief_label.tl` (63 lines) and `_work/brief_label_test.tl`
(233 lines). The review-round numbering that file added exists to keep two
reviews of one item under distinct strings; a fresh `gitboard session new`
per review claim already guarantees that, so the numbering has no job left.
`_work/brief_label.tl` carries no `.cosmic-coverage` row
(`grep -n "brief_label" .cosmic-coverage` → no output), so nothing is
removed from the ratchet; `_work/brief.tl`'s row does move —
`.cosmic-coverage:11` is `["_work/brief.tl"] = {["covered"] = 73, ["total"] = 84}`
and both numbers fall as the branch goes. Hand-edit that one row, as
README.md:262 directs ("Prefer hand-editing the one row your change
actually moved"); do not run `--make coverage --baseline` here.

`_work/doctrine.tl` (419 lines), the `orchestrate` topic's first bullet
at lines 281-289 — the paragraph beginning "Use a distinct session per
agent: `<kind>-<handle>-<orch8>`" through "A lost race is the lock
working". Replace the label recipe and its `<orch8>` rationale with the
minted-id one: one `gitboard session new` per agent, passed as
`--session` (or exported as `GITBOARD_SESSION`); the ids are 128-bit, so
two concurrent orchestrators cannot mint the same one and no derivation
from the orchestrator's own identity is needed. Keep the surrounding
sentences (atomic batch, overlap refusal, "Only refresh grants
authority", "A lost race is the lock working") untouched. The later
review bullet's "each under its own minted `review-<handle>-<orch8>`
label — `brief review ID` fills it into the body it hands the agent, so
claim under the string its own verdict line names" must change with it:
claim first with a minted session, then `brief review ID` fills that
claim into the body.

`_work/gitcommands.tl`, the `brief` summary at lines 174-183: "including
the session label this kind's own claim belongs under (also named on the
closing verdict line)" becomes a statement that the brief fills the
session the item is already claimed under, and that a review brief
refuses when there is none.

`_work/brieftext_review.tl` needs no text edit — `<REVIEW_SESSION>` at
lines 121, 129, 131, 133, 201, 209, 211, 213 keeps its name and simply
receives a value `verdict --session` accepts.

Tests land in a new `_work/brief_session_test.tl` (test files carry no
`.cosmic-coverage` row: `grep -c "_test.tl" .cosmic-coverage` → `0`;
`_work/brief_test.tl` is 438 lines and too near the cap to grow by four
cases). Four cases, each on a fixture built the way `_work/brief_test.tl`
already builds one:

1. a builder brief for a claimed item names that item's exact `it.claim`
   on its verdict line, and the string matches `^[0-9a-f]{32}$`;
2. a review brief for an item claimed by a session that is NOT on
   `it.builders` fills that same string into `<REVIEW_SESSION>`, so the
   body's `gitboard verdict ... --session <value>` would pass
   `_work/claimsession.tl`'s `is_id`;
3. a review brief for an item whose active claim IS on `it.builders`
   refuses, emits no body, and names `gitboard session new`;
4. a refine brief for an unclaimed item succeeds, and its verdict line
   contains neither `claim it as` nor any `<kind>-<handle>-` label.

## Non-goals

- **Do not touch what the mutating verbs accept.** `_work/claimsession.tl`'s
  `is_id` (32 hex chars) and `_work/gitclaim_cli.tl`'s `resolve_caller`
  (lines 17-24) stay exactly as they are, refusal string included. The
  32-hex gate is the newer, deliberate side of this mismatch and the
  frozen wall here; the labels are what move. `_work/preparation_receipt.tl`
  validates receipt sessions through the same `is_id` (lines 41 and 150),
  so relaxing it would have to move receipts too.
- **Do not change `_work/session.tl`'s environment ladder** or `worktree`'s
  use of it. Its own refusal already names the mismatch usefully (see
  Evidence), and `show`'s `session: ... (from CLAUDE_CODE_SESSION_ID)` line
  keeps its job of telling a caller what `worktree` will present.
- **The `brief --session` / `--receipt` asymmetry is out of scope.**
  `bin/gitboard brief builder rs8c_for0 --session $(bin/gitboard session new)`
  answers `gitboard-brief: --session requires a builder --receipt`
  (`_work/brief.tl:311`, `_work/preparation_receipt.tl:218`) while omitting
  `--session` succeeds. That flag means "receipt caller", not "the session
  to name", and this change does not alter it — it belongs to its own item.
- No new verb and no new flag: nothing is added to `_work/gitcommands.tl`'s
  declarations, `_work/gitboard.tl`'s dispatch, or `_work/gitverbs.tl`.
