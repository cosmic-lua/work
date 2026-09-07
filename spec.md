## Evidence

work#76's review found `_work/gittake.tl`'s `take_open` seeds a `ci_checks` row from the head sha its own `git ls-remote` already fetched — but no existing test exercises `take_open`'s happy path past that `ls-remote` call, because nothing in `_work` mocks `child.run` the way `_work/gh_test.tl`'s `api.transport` seam mocks HTTP calls. The two pre-existing `take_open` tests both bail on earlier refusals (`_work/gittake_test.tl:246,274`), and the CI-row seed this item added has zero coverage — reviewed and accepted by inspection only, symmetric with the tested `--pr N` path.

## Change

Add a `child.run` mocking seam usable by `_work` tests — either a swappable `_work.child.run` field (mirroring `api.transport`'s shape) or a small `_work/childstub.tl` helper — and one test exercising `take_open`'s full happy path (a fake remote that reports the branch exists, a fake `gh.open_pull` success) asserting the seeded `ci_checks` row's `state` and `head_sha`.

## Non-goals

No change to `take_open`'s behavior; no broader child-process mocking framework beyond what this one seam needs.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

A test exercises `take_open` end to end (past its `git ls-remote`) without a real network call, and asserts the seeded CI row.
