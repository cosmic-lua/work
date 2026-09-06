## Evidence

`bin/gitboard` runs one pinned release of cosmic-lua/work
(`bin/gitboard.pin`: `url = …/releases/download/2026-09-06-9dea3f3/gitboard`,
`sha256 = 7a8498…`), and every push to cosmic-lua/work's main publishes
a new release (`.github/workflows/release.yml` there). On 2026-09-06
ten PRs landed on cosmic-lua/work after 9dea3f3 — #44 (briefs name the
GitHub reach), #45 (`tight:` headroom flag on show), #46 (`new` prints
the handle), #47 (`brief --out FILE`), #49 (the mutation-step
sentence), #50 (`done`'s refusal names `done`), #51 (`absent:` paths on
show), #52 (a running-CI diff no longer deadlocks `take`), #53 (board
writes refused from a linked worktree), #54 (ratchet recovery in the
builder brief, "commit before mutating") — and none of them reach any
session until this pin moves: the orchestrator that landed them was
still hitting the #52 deadlock and hand-writing the #44/#54 sentences
into every prompt at the end of the pass.

Ready when: in a cosmic-lua/work checkout, `git fetch origin main &&
git log --oneline -1 origin/main` names a commit at or after PR #54's
merge, and the cosmic-lua/work release list carries a tag
`2026-09-06-<sha7>` for that commit (or a later one) with a `gitboard`
asset.

## Change

`bin/gitboard.pin`: set `url` to that release's `gitboard` asset and
`sha256` to the asset's actual digest (`curl -sL <url> | sha256sum`),
both fields in one commit, comment header unchanged. Then, from this
checkout, `bin/gitboard sync` must end `gitboard-sync: state is
current` and `bin/gitboard show --todo 0 | head -3` must print todo
rows (the #48 flag; if #48 has not merged, `bin/gitboard help show`
must at least run under the new pin) — the run is for the builder,
never pasted into the PR body (`gitboard help build`: the body carries
no evidence — CI is the proof). `bin/cosmic --make ci` ends `ci: PASS`
(the pin file is data; the gate proves nothing else broke).

## Non-goals

No change to `bin/gitboard` itself, and no change to `skills/work/`.
