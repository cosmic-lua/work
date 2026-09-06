# friction: 2026-09-06 work5-routine

Filed at pass-end with 5 of 6 spawned agents still in flight
(`review-70P4_YBPd-748ecc95`, `build-0oBN_Fa6X-748ecc95`,
`build-LVYj_DA0K-748ecc95`, `build-vmX5_zQH2-748ecc95`,
`research-IOA7_CLf5-748ecc95`) — a bounded pass never waits on a wave
agent. Their sections will be appended to this item's spec as each
reports and its transcript is run through `_tool/friction.tl`, per the
friction doctrine's "none skipped" rule; this is not a second pass, just
this same wave's reconciliation completing asynchronously.

## build 70P4_YBPd

rework round, PR #1744.

numbers: events=50 tool_calls=10 wall=153s tokens in=20/out=536/cache_read=523302/cache_create=65276;
by tool Bash=8/Edit=1/Read=1; errors=0; repeated commands: x2 reading
`docs/guides/lint.md` (re-reading the same file after the edit to confirm
it, not a mistake).

Agent's own account: none. The task was well-scoped — the reviewer's
quoted lines matched the file exactly, the sibling fix in
`quickstart.md` (via `git show`) gave a clear model of intent, and the
`_cli/lint.tl` diff in the same commit spelled out the exact new
behavior needed to write accurate prose. `bin/cosmic --make fetch` and
`--make ci` both succeeded on the first try.

## build 0oBN_Fa6X

numbers: events=252 tool_calls=63 wall=887s tokens in=128/out=1490/cache_read=5911281/cache_create=104723;
by tool Bash=46/Edit=7/Grep=1/Read=6/ToolSearch=1/mcp__github__create_pull_request=1/mcp__github__get_file_contents=1;
errors=3 (2× `--make ci` failing mid-iteration while landing the new
cast's ratchet updates, self-corrected; 1× a `get_file_contents` lookup
on a path that doesn't exist, self-corrected); repeated: iterated on
`_types/gentype_defs.tl` (x6), `cosmic/zip.tl` (x3, the temporary
repro edit + revert), `docs/design/cast-sites.tsv` (x2).

Agent's own account: the fix itself (route `_types/gentype_defs.tl`'s
zip read through `cosmo.zip` directly) worked on the first real
attempt; verified per the orchestrator's substitute repro steps (no
`Hkal_OAFy` branch available). Real friction: the one-line fix
introduced a new justified cast (`handle as zip.Reader`), which
cascaded into TWO separate committed ratchet floors
(`_build/casts_baseline.tl`, then `docs/design/cast-sites.tsv`) not
mentioned by the spec's gate step — cost ~10 calls tracing
`_build/casts.tl`/`_build/cast_sites.tl` for the regen incantations
and a classification taxonomy with no documented enum (resolved by
finding `cosmic/zip.tl`'s own identical site and reusing its
`userdata boundary` class). Its own suggested countermeasure (a
one-line pointer in AGENTS.md/spec templates: "a new cast may require
rebaselining `_build/casts_baseline.tl` and `docs/design/cast-sites.tsv`")
is new and not yet filed as a board item — left for a follow-up triage
pass rather than filed reactively mid-reconciliation, alongside its
second suggestion (document the cast-site classification enum in
`_build/cast_sites.tl`'s own doc comment).

## build LVYj_DA0K

numbers: events=368 tool_calls=95 wall=829s tokens in=192/out=2237/cache_read=7533286/cache_create=86585;
by tool Bash=65/Edit=10/Grep=9/Read=7/ToolSearch=1/mcp__github__create_pull_request=1/mcp__github__get_tag=1/mcp__github__list_releases=1;
errors=5 (2× `find -iname` on `o/_types` returning no matches, benign;
2× Edit refused before the target file was Read first, self-corrected;
1× a `--make ci` truncated-output read, re-run); repeated: iterated on
`cosmic/errno.tl` (x6), `cosmic/net/init.tl` (x3),
`cosmic/quicksand/proc.tl` (x3), `docs/design/casts.md` (x3),
`3p/cosmos/cosmos_pin.tl` (x2).

Agent's own account: redid the pin bump, the `net/init.tl` fix, and
the four cast removals cleanly per the IMPORTANT section's
instructions (no wasted search for the vanished branch). One
unplanned-but-required fix: removing the casts left
`docs/design/casts.md`'s "binding constant by name" section quoting a
now-deleted source line, failing the `doc-citation` lint check;
repointed the citation at `quicksand/caps.tl`'s still-open,
same-shape `unix.CAP` site (tracked by a separate item) rather than
leaving the doc stale — required for `ci` to pass, not scope creep.
Minor friction locating the exact upstream commit for the
`unix.socketpair` annotation fix (subject didn't mention "socketpair",
~2 extra calls) and confirming `unix.CAP`'s shape independently since
the spec's Non-goals didn't explain WHY `caps.tl` was out of scope
(~1 extra call) — both appropriately cautious verification, not
wasted work.

**What this build did NOT anticipate, and could not have from its own
brief: `bin/cosmic.pin` was never bumped to a release carrying
`RNb7_b0tV`'s fix (see Orchestrator section below) — its own local,
warm `--make ci` run was green, but the PR's cold `build` CI lane is
red.** This is the same cold-build/pin-staging hazard `rLV8_r8a5`'s
own spec explicitly named and planned around for its OWN Non-goals —
this item's spec did not carry the same warning even though it is the
identical shape (a checker fix consumed before its pin bump lands).

## research IOA7_CLf5

numbers: events=120 tool_calls=31 wall=285s tokens in=56/out=219/cache_read=1984266/cache_create=67052;
by tool Bash=21/Edit=1/Grep=1/Read=7/Write=1; errors=3 (2× a malformed
`Read` call — offset passed as a bare second positional int instead of
the named `limit` field, self-corrected); repeated: re-read the
recreated patch file and re-ran `rm -rf o/3p/tl && --make fetch` twice
each (rebuilding after a patch-syntax retry, not a mistake).

Agent's own account: pre-empted the dead branch cleanly (brief's
IMPORTANT section already said it was gone, 0 wasted search calls) and
recreated the missing patch entry from the sibling
`narrow-pcall-zero-return` entry in ~4 calls; confirmed the
independently-derived premise (all 6+3 sites reproduce identically).
Hit one real gotcha: a first attempt at the patch entry's `note` field
used `..` string concatenation for readability, and `fetch` refused it
("a patch holds literals only; found '.' after a value") — patch files
are Teal literal data, not executable Teal, so no operators of any
kind. Cost ~2 tool calls. The agent's own recommended fix (a one-line
"no string concatenation" gotcha in `_make/patch.tl`'s doc comment) is
new and not yet filed as a board item — left for the orchestrator to
triage in a follow-up pass rather than filed reactively mid-reconciliation.

The agent's own key finding — closing the item outright, since the 2
sites it targeted already carry a working, lint-compliant fix — also
surfaced that this item, like `LVYj_DA0K`, had no `repo:` field and its
`brief review` defaulted to `cosmic-lua/work` until the orchestrator
fixed it (same class of gap as the countermeasure already filed in
`3IxHqrApflNsmHz3Uj0eUxZCzX8` — see Orchestrator section below); a
second occurrence in the same pass reinforces rather than duplicates
that finding.

## build vmX5_zQH2

numbers: events=65 tool_calls=14 wall=231s tokens in=30/out=74/cache_read=939659/cache_create=72131;
by tool Bash=7/Grep=2/Read=5; errors=0; repeated commands=0; no edit made
(correctly stopped before touching code).

Agent's own account: verified the spec's file-scope before editing (per
this repo's own "wc -l every file the Change names" rule) and found all
three named files (`_types/gentype_parse.tl` 496/500,
`_types/gentype_render.tl` 489/500, `_types/gentype_test.tl` 499/500)
already within 1-11 lines of the 500-line cap, needing an estimated
25-45 new lines each. Stopped correctly rather than widen scope to a
file split on its own judgment — filed by the orchestrator as child
item `qdDs_EN9Z` for a structural respec (this item is now a container).
The agent's own countermeasure — "the spec's own Evidence section could
have included `wc -l` on the files it names ... which would have caught
this before the item was ever pulled" — is already covered by existing
board item `AY6h_bM0B` ("spec bar: flag a Change-named file already
within ~20 lines of the 500-line cap"); no new item filed for it.

## review 0oBN_Fa6X (PR #1747)

numbers: events=119 tool_calls=29 wall=356s tokens in=52/out=249/cache_read=1738688/cache_create=61927;
by tool Bash=18/Edit=1/Read=4/ToolSearch=1/mcp__github__actions_list=1/mcp__github__enable_pr_auto_merge=2/mcp__github__pull_request_read=2;
errors=2 (1× read a generated file before fetching had produced it,
self-corrected; 1× `enable_pr_auto_merge` rejected a lowercase
`mergeMethod: "squash"` — the GraphQL enum wants `"SQUASH"`, fixed on
retry); repeated: re-read `cosmic/zip.tl` (x2, before/after its
mutation-test edit).

Agent's own account: accepted, cast justified and correctly
classified, mutation test reproduced the exact original failure and
confirmed the fix. One near-miss: its checkout's local `main` was
stale relative to the PR's real base, producing a spurious 90-file
diff on the first `git diff main...HEAD` before a `git fetch`
corrected it — flagged as a brief-improvement candidate (note that a
fresh worktree's local `main` may need fetching before diffing against
it), not yet filed as its own item.

## build q1bW_VFz2 (bin/cosmic.pin bump, PR #1748) — orchestrator took over mid-task

The spawned builder agent (`build-q1bW_VFz2-748ecc95`) correctly
triggered the `release.yml` workflow_dispatch on its first attempt,
then reported "still building" or equivalent across **five separate
resumes** (`SendMessage`-driven re-invocations, ~69k-94k cached input
tokens each — roughly 350k+ tokens total) without ever completing the
sha256 download/verify, the `bin/cosmic.pin` edit, the cold gate, or
the PR. Each resume re-loaded its full context just to re-check the
same external state and stop again. The orchestrator eventually
checked the release run directly (`mcp__github__actions_get`
/`list_workflow_jobs`, 2-3 calls, near-zero cost by comparison), found
the release had already published, and did the entire remaining
Change itself (download, sha256 verify, edit, cold `--make fetch &&
--make ci`, commit, push, PR #1748) directly rather than resuming the
agent a sixth time.

**This is the single largest cost in this pass** — roughly 5-6x more
tokens spent on repeated "still waiting" resumes than the entire
actual task (download + verify + edit + cold gate + PR) cost when done
directly. **Made the difference**: a spawned subagent has no durable
way to wait on external state across its own turns — unlike the
orchestrator, which has `ScheduleWakeup`/`Monitor` for exactly this,
a builder agent that hits "the next step depends on an external,
slow-to-complete process" can only end its turn and hope to be resumed
with the same full context reloaded, which is what happened five
times running. **Countermeasure**: `help orchestrate`/`help build`
should say explicitly that a builder step depending on slow external
CI/workflow completion (not just the PR's own gate) is the
ORCHESTRATOR's job to poll (cheap, targeted GitHub API calls) and hand
back to the builder only once the state changes — never delegate an
open-ended "wait for external state" step into a spawned agent's own
brief. Filed as board item `1alS_QzlJ` for the `work`/`orchestrate` skill
to make this division of labor explicit.

## review q1bW_VFz2 (PR #1748, bin/cosmic.pin bump)

numbers: not machine-extracted (subagent transcript exceeded a size
that made `_tool/friction.tl` impractical to run this late in the
pass); reported tool_uses=29, duration_ms=328099 per the task
notification's own usage line.

Agent's own account: accepted, after independently re-downloading the
release asset and `SHA256SUMS` (not trusting the PR body's claimed
hash), recomputing sha256 locally, and separately confirming the
release tag's commit ancestry against #1745's merge commit via
`git merge-base --is-ancestor`. Also independently confirmed the root
cause by pulling PR #1746's actual `build` job log rather than trusting
the spec's paraphrase, and ran its own genuinely cold
`--make ci` on the new pin (289/3342, green). Minor friction: resolving
the short-form merge-commit/tag references in the spec into full SHAs
`git merge-base` would accept cost ~4 extra tool calls (three
GitHub API round-trips) — worth a future spec convention of citing
full SHAs alongside short ones for exactly this kind of independent
verification.

## Orchestrator

- **Goal**: reconcile the previous pass's two `doing` items before filling
  the wave. **What happened**: `0oBN_Fa6X` was `state: building`, claimed by
  a dead prior-pass session (`build-0oBN_Fa6X-fe8c92c8`) with no PR and no
  pushed branch. A bare `drop` was refused (`REFUSED: ... is
  build-0oBN_Fa6X-fe8c92c8's live claim ... abandon a dead session's with
  --force`) even though the claiming session no longer exists in any
  process — cost: 1 extra tool call. **Made the difference**: the tool has
  no way to distinguish "live claim, different session" from "dead session,
  claim never released" other than the caller asserting `--force`; there is
  no lease-expiry surfaced in `show`'s field list to check first.
  **Countermeasure**: `help drop`/`show` could print the claim's age or a
  "stale (no matching live process)" hint so an orchestrator doesn't need to
  hit the refusal once per dead claim to learn it needs `--force`.

- **Goal**: re-claim `70P4_YBPd` (state `rework`, verdict `request changes`,
  PR #1744, original claim `build-70P4_YBPd-fe8c92c8` from a dead prior
  pass) to spawn a rework builder, per `help build`: "`request changes` —
  rework on the same PR". **What happened**: `take 70P4_YBPd --session
  build-70P4_YBPd-748ecc95` (no `--force`) succeeded, but the verb it
  recorded was `review` ("review 3ItZVev6 claimed by build-70P4_YBPd-...")
  and the field `show` prints for the new holder is `reviewer:`, with the
  original `claim: build-70P4_YBPd-fe8c92c8` left untouched; the verdict
  line read "3ItZVev6's review is yours — verdict when done consumes the
  claim". Nothing in `help take`, `help build`, or `help review` documents
  a `reviewer:` field distinct from `claim:`, or says which one a rework
  session should expect to hold, or that the take verb logs a rework claim
  under the `review` verb name. Cost: ~10 minutes and several `show`/`help`
  reads cross-checking whether the claim I held was actually a rework claim
  or an accidental review claim on a PR that had already been reviewed (no
  new commits since the reviewed head, so a fresh review made no sense).
  Proceeded on the strength of `brief builder 70P4_YBPd`'s own verdict line
  ("builder brief for «70P4_YBPd», claim it as build-70P4_YBPd-748ecc95"),
  which agrees with what `take` recorded, as the tie-breaker.
  **Made the difference**: no doctrine text names the `reviewer:` field or
  says a rework claim reuses the review verb/lease. **Countermeasure**:
  `help build` or `help system` should state explicitly that a rework claim
  is recorded the same way a review claim is (same verb, same `reviewer:`
  field, same "consumes the claim" wording) so an orchestrator doesn't have
  to infer it from a brief's verdict line under time pressure.

- **Goal**: claim `LVYj_DA0K` and mint its builder brief. **What happened**:
  `show LVYj_DA0K` had no `repo:` field at all (unlike its sibling
  `0oBN_Fa6X`, which explicitly carries `repo: cosmic-lua/cosmic`), and
  `brief builder LVYj_DA0K` silently defaulted the "Where to work" line to
  `cosmic-lua/work` (the board repo itself) instead of `cosmic-lua/cosmic`
  — the item is entirely about `cosmic/errno.tl`, `cosmic/net/init.tl`, and
  `3p/cosmos/cosmos_pin.tl`, so building against the board repo would have
  been a silent, wrong target. Caught only by reading the brief's "Where to
  work" line closely against the item's actual content before spawning.
  Fixed with `gitboard set LVYj_DA0K --repo cosmic-lua/cosmic`. Cost: ~3
  minutes and 2 extra tool calls; would have been a wasted agent run (build
  against the wrong repo, no PR possible) had it gone unnoticed.
  **Countermeasure**: `brief builder`/`brief research` should refuse (like
  the CI-still-running refusal) when an item has no `repo:` field, rather
  than silently defaulting to the board repo — a missing repo is exactly
  the kind of fact-check the tool already does for other preconditions.
  Filed as board item `3IxHqrApflNsmHz3Uj0eUxZCzX8` (unparented, in triage),
  bundled with the related unpushed-branch finding below.

- **Goal**: reuse "resume from branch X (committed, unpushed)" as written
  in three separate specs (`0oBN_Fa6X` → `Hkal_OAFy`'s branch `3Iw35aAO`;
  `LVYj_DA0K`'s own branch `3Iw4Klc9`; `IOA7_CLf5`'s draft-patch branch
  `3IpBKtB8`). **What happened**: all three branches are gone —
  `git ls-remote origin 'refs/heads/<branch>*'` returns nothing for each,
  because each was committed inside a PRIOR session's ephemeral remote
  container (this project runs orchestrator sessions as fresh, disposable
  cloud containers, not a persistent developer machine) and never pushed;
  the container was reclaimed before this pass started. `help build`'s own
  stop-short instruction ("Leave your diff committed on the item branch
  (unpushed), never reverted: the respec starts from it") is exactly what
  produced this — sound advice on a persistent machine, silently fatal
  here. Cost: 3 × one `git ls-remote` round-trip to discover each was gone,
  plus rewriting each affected brief's bounce-context to instruct the
  spawned agent to re-derive the referenced work from the spec's Evidence
  prose instead of resuming a branch, and (for the two new builders) to
  push their branch even on a stop-short instead of leaving it local-only.
  No item outright failed, but the "resume, don't restart" time savings
  the specs promised could not be honored, ~10-15 minutes of orchestrator
  time reconstructing intent from prose across three items.
  **Countermeasure**: filed as board item `3IxHqrApflNsmHz3Uj0eUxZCzX8`
  — `help build`'s stop-short guidance should tell a builder to PUSH its
  WIP branch (no PR needed) rather than leave it local-only, since this
  project's actual environment cannot guarantee a local commit survives to
  the next session.

- **Goal**: get `LVYj_DA0K`'s PR #1746 to a reviewable (green) state.
  **What happened**: its `build` CI lane was red —
  `cosmic/errno.tl:52`/`:97`: `got <any type>, expected integer | nil`
  — even though the builder's own local `--make ci` was green. Traced
  to `bin/cosmic.pin` on `main` still naming a release
  (`2026-09-06-d45e498`, published 01:59:19Z) that predates
  `RNb7_b0tV`'s merge (PR #1745, 11:11:43Z): CI's `build` lane is a
  genuinely cold build, so generation 1 runs the PINNED RELEASE's own
  compiled-in (old, buggy) `gentype_parse.tl`, not the tree's fixed
  one — exactly the staging hazard `AGENTS.md`'s cold-build rule names
  ("land the checker first, bump `bin/cosmic.pin`... then land the
  code that needs it"). `RNb7_b0tV`/#1745 landed the checker but the
  pin-bump step never happened, and no release built after the merge
  exists yet (`release.yml` is a daily cron). Cost: ~15 minutes reading
  the CI job log, cross-referencing `AGENTS.md`, and confirming no
  newer release exists via `list_releases`/`get_latest_release`.
  **Made the difference**: `RNb7_b0tV`'s own PR body and the item's
  own respec (mine, written earlier this pass) never flagged this
  staging requirement, even though a SIBLING item (`rLV8_r8a5`)
  explicitly documents the identical hazard in its own Non-goals
  ("deleting the 2 casts is separate follow-on work that must wait for
  a `bin/cosmic.pin` bump... must carry a `blocked_by` edge on that
  pin-bump item") — the convention is well-established in this
  project, just not consistently applied when a NEW checker fix lands.
  **Countermeasure**: any item whose spec says "once checker fix X
  lands" or is itself a checker/generator fix (`_types/gentype_*.tl`,
  `3p/tl/tl_patch/*`) should carry a template line noting the
  cold-build pin-bump prerequisite for any consumer, mirroring what
  `rLV8_r8a5` already does by hand — ideally the spec bar itself
  flags a checker-surface change with no accompanying pin-bump-tracking
  note. Filed the missing pin bump as board item `q1bW_VFz2` (child of
  `LVYj_DA0K`, which is now a container blocked on it) and posted the
  root-cause + blocker on PR #1746 rather than modifying its (correct)
  diff.

- After `q1bW_VFz2`/PR #1748 merged, `LVYj_DA0K` reverted from container
  back to `state: review` with its original `pr:1746` still recorded —
  but #1746's head (`8647a7e9`) predates the pin bump, so its `build`
  lane was still running against the stale head. Merged `origin/main`
  into the PR branch directly (a plain merge commit, no conflicts —
  both ratchet files auto-merged cleanly), ran a genuinely cold
  `--make ci` locally to confirm green before pushing (289/3342,
  clean), then pushed the merge commit to the PR branch per the
  drive-to-green posture ("push a fix" is the deliverable). No
  countermeasure needed here — this is exactly what `help
  orchestrate`'s reconciliation step expects for a PR that outlived a
  blocking dependency; noted only because it's easy to forget the
  merge-in step after a blocker child resolves.

- **Goal**: get `LVYj_DA0K`'s PR #1746 green after merging in `main`
  (which now carried both #1747 and the pin-bump #1748). **What
  happened**: `ci` failed identically on TWO separate attempts of the
  same run, 40 minutes apart (`invalid key 'E' in record 'unix' of
  type unix` — a DIFFERENT symptom than the earlier `<any type>`
  failure). Root-caused via the job's full log: `.github/workflows/pr.yml`'s
  `ci` job caches `o/` keyed by `hashFiles('bin/cosmic.pin')` alone; this
  PR bumps `3p/cosmos/cosmos_pin.tl` instead, which the key doesn't
  cover, so `restore-keys`' prefix match silently reused a STALE `o/`
  (built under an older cosmos pin, predating `unix.E`/`unix.SIG`
  existing upstream at all) saved from an unrelated commit on `main`.
  This is a real, deterministic, repo-wide CI infrastructure bug — not
  a flake, not this PR's diff — that will hit ANY future PR bumping a
  3p pin without also touching `bin/cosmic.pin`. Cost: ~20 minutes and
  ~4 `get_job_logs`/`actions_get` calls to fully trace (the first tail
  view showed only the symptom; the full log's cache-restore lines
  were the actual smoking gun). **Made the difference**: the exact bug
  class (a cache/artifact surviving a pin bump without invalidating) is
  already a known, named hazard in this project — the surrounding YAML
  comment explicitly states the intent ("a pin bump... starts cold
  instead") for `bin/cosmic.pin` specifically, but the same reasoning
  was never extended to the OTHER pins (`3p/cosmos`, `3p/tl`), and a
  sibling board item (`HNez_qkM2`) had already flagged the analogous
  LOCAL-dev-tree hazard but explicitly asserted "CI is sound" without
  checking that the cache key covers every pin, not just one.
  **Action taken**: filed board item `Qzbr_H1Xg` (initially unparented,
  then re-parented as a child of `LVYj_DA0K` per the same
  stuck-build-files-a-child pattern used earlier for the pin-bump
  blocker — this correctly turned `LVYj_DA0K` back into a container and
  let `take` accept new work despite its still-open, still-unreviewable
  PR), built the one-line `hashFiles()` widening
  myself (`3p/**/*_pin.tl` alongside `bin/cosmic.pin`), verified no
  other workflow uses the same cache pattern, ran the local gate green,
  and opened PR #1749. Posted one standing-down comment on PR #1746
  naming the root cause and the fix PR, per the drive-to-green
  posture's "this is not this PR's failure" branch.
  **Countermeasure**: none filed separately — the fix IS the
  countermeasure; noting here only that `HNez_qkM2`'s own spec should
  be corrected next time it's touched (its "CI is sound" claim doesn't
  hold once a non-`bin/cosmic.pin` pin is what changed).

- Third occurrence this pass of the missing-`repo:`-field gap (after
  `LVYj_DA0K` and `IOA7_CLf5`): a NEW item filed via `gitboard new`
  with no `--repo` (this tool has no way to pass one at creation time —
  confirmed via `gitboard help new`) defaults to `cosmic-lua/work` in
  `take --pr`'s validation ("cannot read PR #1749: GET
  /repos/cosmic-lua/work/pulls/1749: HTTP 404") until `gitboard set
  --repo` is run. This reinforces (does not duplicate) the
  countermeasure already filed in `3IxHqrApflNsmHz3Uj0eUxZCzX8` — three
  for three items I filed and immediately worked myself this pass, so
  the fix (either `new --repo`, or inheriting the parent's `repo:` at
  attach time) would have saved 3 extra `gitboard set` round-trips.

- After `Qzbr_H1Xg`/PR #1749 merged, assumed (wrongly) that
  `rerun_failed_jobs` on PR #1746's existing run would pick up the new
  `.github/workflows/pr.yml` from current `main` via the recomputed
  `refs/pull/1746/merge` ref. It did not: the re-run used the IDENTICAL
  old cache key (`hashFiles('bin/cosmic.pin')` only, same hash prefix,
  same stale restore-key hit) and failed identically a third time —
  costing one wasted re-run + a full job-log re-fetch to notice the key
  hadn't changed. For a `pull_request`-triggered workflow, GitHub uses
  the WORKFLOW DEFINITION as it exists on the PR's OWN branch at the
  time the run is (re-)triggered, not a live recomputation against the
  current base — merging `main` into a stalled PR branch is REQUIRED to
  pick up a base-branch workflow-file fix, exactly like picking up any
  other base-branch fix, and a plain re-run of an existing job can
  never do this since it reuses that run's already-resolved workflow
  file. Fixed by merging `main` into `3IwpNLVH` a second time (clean,
  no conflict — `main`'s only new content since the first merge was
  `.github/workflows/pr.yml` itself), running the gate cold and green
  locally, then pushing — a genuinely new head that resolves its own
  workflow fresh. **Countermeasure**: this is a GitHub Actions platform
  behavior, not a gitboard/project gap — worth remembering rather than
  filing: a workflow-file fix on the base branch needs the SAME
  re-merge treatment as any other base-branch fix on a stalled PR,
  never just a job re-run.

- No other friction: `sync`, `show`, `next`, and the review-comment lookup
  for the bounce context (`pull_request_read get_comments` on #1744, since
  `get_reviews` returned empty — the verdict was posted as a PR issue
  comment, not a submitted GitHub review) all worked as documented on
  first try.
