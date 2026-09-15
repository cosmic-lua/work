Every adversarial review of the claim paths re-derives the same test harness
from scratch, because the one that exists is private.

`_work/snapshot_authority_test.tl` holds the pattern a reviewer needs to attack
the admit side — build a raw claim blob by hand, compose a commit carrying it,
feed it to the real `publication.plan`, assert refusal — as three file-local
helpers: `claim_blob`, `claim_commit`, `denied`
(`grep -n "local function claim_blob\|local function claim_commit\|local function denied" _work/snapshot_authority_test.tl`).

`gitboard help review` asks every reviewer to attack the diff, and the claim
paths are where that matters most. Two reviewers this session wrote throwaway
probe files reproducing those helpers, ran them, and deleted them — one
reporting it as friction, and noting it is exactly the pattern the brief tells
reviewers to repeat every round.

Extract the three helpers into `_work/claimprobe.tl` as an exported testkit and
have `_work/snapshot_authority_test.tl` require it instead of defining them,
so its existing tests keep passing unchanged and the next reviewer imports the
pattern rather than rebuilding it.

Regression: `_work/snapshot_authority_test.tl` is the regression — it must pass
unchanged in behaviour after the extraction, with its local definitions gone.
