## Evidence

Three GitHub rate-limit refusals in one session (2026-09-05 03:12, 03:53,
05:08 UTC), every one returned by the GitHub connector's tools, none by
gitboard. Measured against the live board with `x-ratelimit-used` before
and after each verb, the pinned gitboard (2026-09-05-56acf8e) spends 0
counted calls on `next` and `show`, about 4 on `sync` (three lane reads
plus the CI observations that aged out), and one to three on `take --pr`,
`verdict`, `done` and `brief review` — its ETag cache
(`o/board/o/gh-cache`) turns repeat reads into 304s GitHub does not
charge. While the connector was refusing, the container token gitboard
uses had ~4950 of 5000 calls left in its window. The two are separate
buckets, and the connector's is shared by every Claude session and
subagent the owner runs at once (the two-hourly `/work 9 --routine`
fan-out included).

The subagent prompts push reads onto that bucket because the briefs do
not name a command. `_work/brieftext_review.tl:52` says "CI is
mechanical, but read it fresh on the PR's CURRENT head" and stops there;
`show <ID>` prints `pr: #N` and nothing about CI, so a reviewer reaches
for `pull_request_read`/`get_check_runs` on the connector, and an
orchestrator's environment notes tell it to. Each review costs three to
six connector calls this way, and a builder's push-and-verify loop the
same again — all of it already answered, for free, by
`_work/ciobs.tl`'s observation the board keeps.

## Change

1. `show <ID>` prints the PR's observed CI state on its own line under
   `pr:` — `ci: <state> (head <sha8>, observed <age> ago)` from
   `_work.ciobs.read`, or `ci: unobserved` — so the state and its age
   are one read-only verb away; a state older than the freshness window
   says so (`stale — run sync`).
2. `_work/brieftext_review.tl` step 1 names the command: read CI with
   `bin/gitboard show <ITEM_ID>`; if it is stale or unobserved, `bin/gitboard
   sync` refreshes it through the cache; never through the GitHub
   connector's tools. The one thing the board cannot hand over — a
   failing job's log — gets a `curl -sS -H "Authorization: token
   $GITHUB_TOKEN" https://api.github.com/repos/<slug>/actions/jobs/<id>/logs`
   recipe in the same step, so it also stays on the container token.
3. `_work/brieftext.tl`'s builder template says the same for the
   builder's own CI check after its push: `show`, then `sync` if stale;
   opening the PR remains the builder's one connector call.
4. cosmic's `skills/work/SKILL.md` gains one line for orchestrators:
   subagent prompts route CI and PR reads through `show`/`sync`, not the
   connector, and say why (one shared bucket for every session).
5. Tests: `_work/gitshow_test.tl` asserts the `ci:` line renders for an
   observed, a stale, and an unobserved candidate; `_work/brief_test.tl`
   asserts both templates contain `gitboard show` in the CI step and no
   connector tool name.

## Non-goals

Changing what `ciobs` observes or its freshness window; adding a
`gitboard ci` verb; touching the connector or its token.
