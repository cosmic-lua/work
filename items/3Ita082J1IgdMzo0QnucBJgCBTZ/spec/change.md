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
