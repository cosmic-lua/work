# friction: 2026-09-06 work5 (/work 5 --routine)

## orchestrator
- goal: reconcile the previous wave before filling this one (per `orchestrate`'s step 1).
  actually happened: `gitboard done Hkal_OAFy` lost a push race (1 retry, succeeded as
  no-op — already recorded by a concurrent orchestrator session), and
  `gitboard take eoMl_RZUo --pr 1752` likewise reported "nothing to record" (already
  recorded concurrently). No cost beyond the retries themselves (2 extra calls total);
  the lock behaved exactly as documented.
  contributed: another orchestrator session (same board, different orch8 `f6f470de`)
  is actively working this board concurrently with this pass.
  improvement: none needed — this is the lock working as designed, not a bug. No fix.
- goal: reclaim AY6h_bM0B's review, which showed a `reviewer:` claim with no verdict
  and nothing posted on PR #45, so it read as dead.
  actually happened: `take --force` was correctly refused ("live" claim); left it per
  doctrine's "still running: leave it". It later resolved itself: the concurrent
  session's reviewer posted an accept and PR #45 entered GitHub's merge queue before
  this pass tried to merge it directly (405 "in the merge queue").
  contributed: no visible signal (heartbeat, timestamp) distinguishes "live but
  slow" from "dead" short of trying `--force` (which risks stepping on real work) or
  waiting. `show` prints no claim age.
  improvement: `gitboard show` could print how long ago a claim was made, so an
  orchestrator can judge staleness without guessing or force-probing. Doesn't yet
  pass the spec bar (needs a claim-timestamp field first) — candidate for triage.
- goal: claim `4mpH_hi6v`'s review via `brief review 4mpH_hi6v`.
  actually happened: the verdict line said "fill <WORKTREE>, <HEAD_SHA>, then paste
  the body verbatim" even though nothing in the body needs filling — the item's own
  spec prose quotes the literal strings `` `<WORKTREE>` ``, `` `<HEAD_SHA>` `` as
  example placeholder names inside a `## Non-goals` sentence, and the brief tool's
  placeholder scanner treated that prose as an unfilled placeholder. Cost: one
  extra grep to confirm it was a false positive before proceeding (~1 tool call).
  contributed: `_work/brief.tl`'s placeholder-fill check apparently pattern-matches
  `<UPPERCASE_WORDS>` anywhere in the rendered body, including inside the verbatim
  spec text it is quoting back, not just in template slots it itself inserted.
  improvement: the scanner should only flag placeholders in template-inserted
  regions, not text that came from the item's own spec. A tool fix
  (`_work/brief.tl`), not a doc — ranks above a doc per `bar`'s enablement order.
  Passes the spec bar loosely (clear repro, clear fix direction) but needs the
  exact source location confirmed by whoever picks it up — candidate for triage,
  not filed outright given effort budget this pass.
- goal: fill the wave's last build slot after 4 reviews (N=5), then reviews kept
  arriving as a second concurrent orchestrator session (`f6f470de`) pulled and
  built in parallel with this pass.
  actually happened: `take YA08_4YUN` was refused ("2 diff(s) await a verdict you
  can give and outrank this take") because iltX_EM90 and duSw_TyDF had just
  produced PRs moments earlier. Claimed and spawned those two reviews instead (6
  total this pass). A 7th (`VGEI_R3nE`, pr:49) appeared next but its CI was still
  running (0 of 1 checks done) — `take` correctly refused a review claim on a
  head that hasn't settled, so it was left for the next pass/reconciliation
  rather than forced. Net: 6 review agents spawned, 0 build agents pulled this
  pass despite width N=5, because reviews mechanically outrank pulls and kept
  regenerating as the sibling orchestrator worked.
  contributed: two orchestrator sessions on the same board at once means review
  supply is not bounded by this session's own N — `orchestrate`'s "count against
  N first" assumes one orchestrator driving the wave's pace.
  improvement: doctrine already covers this correctly (never wait, claim what's
  there, leave what CI hasn't settled) — no fix needed. Worth noting for anyone
  tuning N: with concurrent orchestrators, actual review load is not N-bounded.

## candidates
- claim-age on `gitboard show`/`take` refusals (so a "live" review/build claim's
  actual age is visible without a force-probe) — stays here for triage: no
  measured command/output yet (spec-bar's "measured, not inferred" rule), and
  this pass's own experience shows the mechanism already resolves correctly
  without it (the AY6h_bM0B claim turned out live and completed on its own).
  Low priority.
- `_work/brief.tl`'s placeholder scanner treats `<UPPERCASE>` text that is part
  of the item's own quoted spec prose (not a template-inserted slot) as an
  unfilled placeholder (seen on 4mpH_hi6v's brief, which quotes `<WORKTREE>`
  and `<HEAD_SHA>` as example names in its own Non-goals sentence) — stays here
  for triage: real bug, clear repro (`gitboard brief review 4mpH_hi6v`), but no
  measured file:line for the scanner's actual match logic yet.

## agents spawned this pass — all six have now reported; sections below
(qPiX_DdxS, 4mpH_hi6v, eoMl_RZUo, duSw_TyDF, QYqs_nEsq, iltX_EM90)

## review qPiX_DdxS (general-purpose) — accepted, auto-merge enabled (not yet merged); 945s, 55 tool calls
transcript: events=204 tool_calls=55 wall=945s; tokens in=100 out=1312 cache_read=4319987
cache_create=179851; by tool: Bash=34 Edit=2 Glob=3 Read=4 ToolSearch=2
mcp__github__enable_pr_auto_merge=1 mcp__github__get_file_contents=3 mcp__github__get_tag=1
mcp__github__pull_request_read=5; first edit: call 26; 0 errors, 4 repeated commands.

- goal: verify the PR's own "diff touches only 3 files" acceptance claim.
  actually happened: the real diff touches 5 (two ratchet-baseline files and a
  derived TSV also changed); cost ~10 minutes / 6 bash calls to determine this
  was a mandatory gate consequence (reverting the 3 extra files reproduces real
  ratchet failures) rather than scope creep, by cross-checking against the
  in-tree precedent (`cosmic/coverage/init.tl`'s identical `find_ccov`).
  contributed: the item's own `## Acceptance` section made a falsifiable claim
  ("touches only 3 files") that was true at spec-writing time but wrong once a
  from-scratch `find_ccov` was shown to trip the casts/nil-returns/cast-sites
  ratchets — the builder's own PR description already flagged this same gap.
  improvement: a spec template for any "copy `find_ccov`'s shape" slice should
  name the ratchet files it will also touch up front, so `## Acceptance` doesn't
  make a claim every reviewer has to re-litigate. Doc/template fix, not a gate.
- goal: read `tool/net/definitions.lua` from the cosmopolitan release tag to
  verify `cosmo.cov.budget`'s contract independently. actually happened:
  `mcp__github__get_file_contents` failed outright (344KB response over the
  tool's token cap) and initially returned only a truncated first line with no
  clear signal why; recovered by saving the raw response to a file and using
  python3/jq instead, costing 3 extra bash calls. contributed: no size-aware
  guidance surfaced until after the first failure. improvement: none needed —
  the tool's own error message named the exact recovery path once it fired.

## review 4mpH_hi6v (general-purpose) — accepted, merged, done; 960s, 83 tool calls
transcript: events=327 tool_calls=83 wall=960s; tokens in=164 out=1233 cache_read=7236310
cache_create=109579; by tool: Bash=56 Edit=2 Read=7 TaskStop=1 ToolSearch=5
mcp__github__actions_list=2 mcp__github__enable_pr_auto_merge=1 mcp__github__merge_pull_request=1
mcp__github__pull_request_read=8; first edit: call 34; 8 errors, 3 repeated commands.

- goal: run the pinned `bin/gitboard` the orchestrator's brief said the fresh
  clone "carries." actually happened: a `cosmic-lua/work` clone has no
  `bin/gitboard` at all — the trust-root wrapper lives in the `cosmic-lua/cosmic`
  checkout, and `gitboard` itself is a build target (`cmd/gitboard` →
  `o/bin/gitboard`); cost ~3 tool calls (`ls`, `find /`, reading the wrapper)
  before landing on invoking cosmic's own `bin/gitboard` with `GITBOARD_DIR`
  pointed at the fresh work clone. contributed: this orchestrator's brief text
  (same root cause as the QYqs_nEsq section above — "bin/gitboard ... fetches
  its own pinned release" is simply wrong for a `cosmic-lua/work`-only clone).
  improvement: brief text should say to invoke `bin/gitboard` from a
  `cosmic-lua/cosmic` checkout (or build `o/bin/gitboard` locally) with
  `GITBOARD_DIR` pointed at the fresh clone under review — a brief-writing fix,
  already applied to future briefs this session writes.
- goal: confirm PR #47 actually merged after enabling auto-merge. actually
  happened: `mergeable_state`/`merged` flickered `unknown`/`clean`/`false` for
  ~90s while the required merge queue re-ran CI on the merge commit before the
  real push to main; a single check right after enabling auto-merge would have
  under-reported "still open". Cost ~5 polling round-trips over ~2 minutes.
  contributed: real merge-queue latency on this repo, not a bug.
  improvement: none needed — worth knowing for future reviewers that this
  repo's merges take a full CI cycle after auto-merge fires, not an instant PUT.
- also: a bare `sleep 30` was blocked by harness policy, and `Monitor`'s
  shell-only scope can't call the `mcp__github__*` tools needed to poll merge
  status, so the agent fell back to polling GitHub's REST API via `curl` in a
  backgrounded bash loop — a real seam between Monitor and MCP-only checks, not
  spec/brief friction.

## review eoMl_RZUo (general-purpose) — request-changes; 867s, 36 tool calls
transcript: events=145 tool_calls=36 wall=867s; tokens in=70 out=403 cache_read=2536032
cache_create=123051; by tool: Bash=24 Grep=2 Read=3 ToolSearch=2 mcp__github__add_issue_comment=1
mcp__github__pull_request_read=4; first edit: none; 0 errors, 2 repeated commands.

Findings posted to cosmic-lua/cosmic#1752: `docs/contributing.md`'s new sentence
overstates gate coverage (claims both doc gates scan `README.md`/`AGENTS.md`,
but `doc_paths_test.tl`'s `ROOTS` only covers `docs`/`skills` — confirmed
`AGENTS.md` already contains an unchecked path-shaped backtick span). Item now
awaits rework on the same PR; no builder currently assigned to it.

- goal: run `gitboard verdict` immediately after cloning. actually happened:
  first call failed "no item matches <id>" for an id copied verbatim; running
  `gitboard sync` then `show` first, then retrying the identical verdict
  command, succeeded. cost ~2 extra calls. contributed: unclear (possibly the
  board clone needed a sync pass before the item resolved) — nothing in the
  task or `gitboard help` flagged that `sync` might be needed before `verdict`.
  improvement: a note in the review brief ("run `gitboard sync` first if
  verdict reports no matching item") would save the round trip — same class of
  gap as the full-refs-fetch issue below, both about a fresh board clone not
  being immediately query-ready.

## review duSw_TyDF (general-purpose) — request-changes; 731s, 55 tool calls
transcript: events=218 tool_calls=55 wall=731s; tokens in=108 out=894 cache_read=4034520
cache_create=79430; by tool: Bash=45 Edit=2 Read=1 ToolSearch=1 Write=2
mcp__github__add_issue_comment=1 mcp__github__pull_request_read=3; first edit: call 20;
2 errors, 2 repeated commands.

Findings posted to cosmic-lua/work#48: the `... N more` trailer's `shown ==
#todo` boundary is untested (mutation-confirmed: flipping `>` to `>=` at
`_work/gitview.tl:239` passed the full suite unchanged), and the new `--todo`
CLI parsing/refusal path in `_work/gitboard.tl:224-233` has no test at all.
Item now awaits rework on the same PR; no builder currently assigned to it.

- goal: run `bin/gitboard verdict` per the brief. actually happened:
  `bin/gitboard` doesn't exist in a `cosmic-lua/work` clone (only in
  `cosmic-lua/cosmic`, as a build target); cost ~2 calls to discover and build
  `o/bin/gitboard` from the right checkout. contributed: same brief inaccuracy
  as qPiX_DdxS/4mpH_hi6v above — three independent reviewers hit this
  identically, which is itself the strongest signal in this log that it's a
  real, reproducible brief defect rather than an agent-side mistake.
  improvement: fix the orchestrator's reviewer-brief template once, not
  per-brief — "clone `cosmic-lua/cosmic` for the `gitboard`/`cosmic` binaries;
  point `GITBOARD_DIR` at the fresh product-repo clone under review."
- goal: run `gitboard verdict` against the item id right after cloning.
  actually happened: `no item matches <id>`; fixed with a detached-HEAD
  `git fetch origin '+refs/heads/*:refs/heads/*'` (~4 extra commands, since the
  checked-out branch blocked a direct fetch onto it). contributed: a plain
  `git clone --branch X` only populates `refs/remotes/origin/*`, not the local
  `refs/heads/*` gitboard's store reads from — the SAME root cause eoMl_RZUo's
  reviewer hit as an unexplained "sync fixed it," and QYqs_nEsq's reviewer hit
  too (documented there as a full-refs-fetch need). Three of six reviewers this
  pass hit some variant of this. improvement: this is now the single highest-
  leverage fix in this log — put one exact command in the reviewer brief
  template: `git fetch origin '+refs/heads/*:refs/heads/*'` (or equivalent)
  right after clone, before any gitboard verb.

## review QYqs_nEsq (general-purpose) — accepted, merged, done; 569s, 64 tool calls
transcript: events=251 tool_calls=64 wall=569s; tokens in=126 out=1507 cache_read=4777072
cache_create=84588; by tool: Bash=39 Edit=2 Monitor=1 Read=4 TaskStop=2 ToolSearch=3
mcp__github__actions_list=3 mcp__github__enable_pr_auto_merge=1 mcp__github__merge_pull_request=2
mcp__github__pull_request_read=7; first edit: call 20; 8 errors, 3 repeated commands.

- goal: run `bin/gitboard` per the brief's literal command. actually happened: `bin/gitboard`
  does not exist in a fresh clone (only `bin/cosmic`); one failed exec (call 13) plus an `ls
  bin/` to discover the repo builds `gitboard` via `cmd/gitboard` + `bin/cosmic --make build`.
  contributed: the review brief (this orchestrator's own hand-written text, since `gitboard
  brief` doesn't emit reviewer briefs with a build step) says "bin/gitboard ... fetches its
  own pinned release" as if it ships pre-built. improvement: fix the ORCHESTRATOR's brief
  template (this session's prompt text) to say `bin/cosmic --make build` then `o/bin/gitboard`,
  not `bin/gitboard`. A brief-writing fix, not a tool fix — already applied to future briefs
  this session writes; worth a similar correction in whatever wrote the `review` doctrine text
  the orchestrator paraphrased from, if it says the same.
- goal: run `gitboard verdict` against the fresh clone. actually happened: `no item matches
  <id>` (call 37) because a plain `git clone` only carries `refs/heads/main`/PR refs, not the
  board's `refs/heads/items/*`/`ended/*`; fixed with `git fetch origin 'refs/*:refs/*'`. cost:
  1 failed call + 1 fetch. contributed: gitboard's own board-repo data model needs a full-refs
  fetch that a plain clone doesn't do, and the brief didn't say so. improvement: `gitboard help
  review` (or the brief text) could name the exact fetch a reviewer's board-repo clone needs.
- goal: merge PR #46 "directly" per this orchestrator's brief instruction. actually happened:
  `merge_pull_request` refused twice (calls 40-41: "merge commits not allowed", "must go
  through merge queue"); fell back to `enable_pr_auto_merge` + polled Actions for the
  `merge_group` run, ~4 extra calls and real wall-clock waiting. contributed: this
  orchestrator's brief said "merge it DIRECTLY" for a board-repo PR without knowing the repo
  now enforces a merge queue (landed by an earlier item, work#44). improvement: the
  orchestrator's own brief text for board-repo accepts should say "enable auto-merge and
  confirm the merge queue lands it", matching what `review` doctrine already says for
  main-repo PRs — this is this session's own paraphrase drifting from repo reality, not a
  gitboard bug.
- also: two tool-shape errors unrelated to the brief (Monitor called with an unsupported
  `untilPattern` param; a bare `sleep 90` blocked by the harness) — agent-side tool usage
  mistakes, self-corrected, not spec/brief/tool friction.

## review iltX_EM90 (general-purpose) — accepted, auto-merge enabled (not yet merged); 838s, 45 tool calls
transcript: events=178 tool_calls=45 wall=838s; tokens in=90 out=765 cache_read=3982471
cache_create=88536; by tool: Bash=35 Grep=2 Read=1 ToolSearch=2 mcp__github__enable_pr_auto_merge=1
mcp__github__pull_request_read=4; first edit: none; 0 errors, 2 repeated commands.

- goal/actually happened: essentially none — the reviewer explicitly reported no
  friction worth logging beyond a single self-corrected `sync`-before-verdict
  ordering issue (same family as the other five reviewers' full-refs/sync gap
  below), costing under a minute. contributed/improvement: n/a — the largest
  item this pass (39 changed files, an 18-group tree-wide prose cleanup) went
  through review with the fewest tool calls and zero errors of any of the six,
  because the spec's measured evidence (exact file:line groups, exact
  normalization rules, an exhaustive two-condition allowlist) left nothing to
  infer. Strongest evidence in this log that the spec-bar's "measured, not
  inferred" rule pays for itself on large diffs specifically.

## this pass's outcome, all six reviews
2 accepted-and-done (4mpH_hi6v/work#47, and QYqs_nEsq/work#46, both merged and
closed by their own reviewer). 2 accepted-with-auto-merge-pending, not yet
confirmed merged (qPiX_DdxS/cosmic#1751, iltX_EM90/cosmic#1753) — orchestrator
to confirm and `gitboard done` once each lands. 2 request-changes, awaiting
rework with no builder currently assigned (eoMl_RZUo/cosmic#1752,
duSw_TyDF/work#48) — next pass's `next`/`take` should surface these as rework,
not fresh pulls.

## cross-cutting finding, promoted from candidates
Three of six reviewers independently hit "no item matches <id>" on `gitboard
verdict`/`show` immediately after a fresh clone, each diagnosing it slightly
differently (a plain `sync` fixed it twice; a detached-HEAD
`git fetch origin '+refs/heads/*:refs/heads/*'` fixed it once) — a plain
`git clone`/`git clone --branch X` does not pull the local `refs/heads/*` (or
equivalent) state gitboard's store reads from, only `refs/remotes/origin/*`.
This is now measured across three independent transcripts (a66a5393,
acf73f01, a163198c — see their sections above) rather than inferred, and
clears the spec bar's "measured, not inferred" test — **but run `gitboard
find` for prior art before drafting a spec for it** (see the entry below:
the very next candidate this session tried to file this pass turned out to
already exist). If `find` comes back clean: either `gitboard help
review`/the review-brief template names the exact fetch command up front, or
(higher leverage, a gate over a doc per `bar`'s enablement order) `gitboard
sync`/`init` against a bare `origin`-only clone auto-detects and fixes this
itself instead of requiring `sync` to be run first by convention.

## orchestrator, post-close: PRODUCT_ROOT bug, filed then found duplicate
- goal: this pass's own `bin/gitboard brief review <id>` calls (this
  orchestrator ran `GITBOARD_DIR=/home/user/work bin/gitboard brief review
  qPiX_DdxS`, sibling-checkout bootstrap) printed a verdict-recording block
  starting `cd /home` instead of `cd /home/user/cosmic`. Traced to
  `_work/brief.tl:227`'s `product_root()`, which computes
  `dirname(dirname($GITBOARD_DIR))` — correct only when `$GITBOARD_DIR` is
  `<root>/o/board` (the cold-start bootstrap), silently wrong under the
  sibling-checkout bootstrap this session actually used, where `$GITBOARD_DIR`
  IS the sibling root with no `o/board` nesting at all.
  actually happened: filed it as a new item without running `gitboard find`
  first — `gitboard new` immediately flagged 3 "similar" matches, one of them
  (`wwWD_cwM5`, opened 2026-09-06T03:19:21Z, hours before this pass) an exact
  prior duplicate: same file, same function, same repro command, same output.
  Closed the new item (`gitboard done <id> --reason not-planned`) rather than
  leave two open items for one bug. Cost: 1 wasted `new` call plus the
  drafting time for a full spec that duplicated existing work; caught
  immediately by the tool's own similarity check rather than persisting.
  contributed: this orchestrator wrote and filed the spec before searching for
  prior art — `gitboard help bar`/`orchestrate` don't say to `find` before
  `new`, and `new`'s own similarity warning is advisory (prints, doesn't
  block), so a session that doesn't read the warning carefully could leave the
  duplicate standing.
  improvement: for THIS session — `gitboard find <keywords>` before drafting
  any new item's spec, not after. Doesn't rank as its own tool fix: `new`
  already surfaces similarity at exactly the right moment, this orchestrator
  just filed first and searched never. No board-fixable countermeasure here,
  a self-correction.
- The pre-existing `wwWD_cwM5` already carries a more complete fix proposal
  than this session's draft would have (existence-checking the candidate
  `bin/gitboard` path rather than a new `GITBOARD_PRODUCT_ROOT` env var) —
  worth noting only because it means this session's own drafted spec
  (discarded) should NOT be resurrected verbatim if `wwWD_cwM5` is ever
  refined further; its own approach is the one to build on.
