Decide how the board records «ulrV_P24b», whose work merged without a board
verdict, and apply that decision so the parent can end.

Facts, all verified 2026-09-15:

- PR cosmic-lua/work#173 was squash-merged to `main` as `6359455b9c46daa6`
  at 02:44:24Z by the goal owner. `main` has since advanced four more
  commits (#174, #175, #176, #177, #178, #179).
- The board's handover for «ulrV_P24b» is `61ae8924a4a4`, recorded at
  01:24:05Z and dropped at 01:30:16Z. That commit is an INTERMEDIATE commit
  on branch `impl/snapshot-publication`: the PR's own final head is
  `2e478cbdf141` ("address snapshot publication review feedback", pushed
  02:34:36Z, after the drop). So the handover is stale twice over — it is
  neither the PR head nor the landed commit.
- No `verdict` entry exists anywhere in the item's 13-entry log.
- `claim` refuses the item outright: the handover is unreachable from `main`
  after the squash merge ("a fresh review claim must not silently capture an
  unrelated base"). The tool's suggested remedy — repositioning local `main`
  onto the handover — makes the review brief compute an EMPTY diff range
  (`61ae8924..61ae8924`), because `brief` derives the range's base from the
  claim base. This is «Ge9j_2iCP» reaching one step further than that item
  currently records.

The decision belongs to the goal owner because it trades off two rules the
system holds at once: "nothing merges without a fresh-context review" and
"the board records what is true". Options:

a. Record it as repair: `verdict accept --force --why` naming the
   out-of-band merge, then `done --landed 6359455b9c46daa6`. Honest about
   the process gap, cheapest, leaves the quality question unasked.
b. Post-hoc review of what actually landed (`7f88ef302..6359455b9`, 134
   files, +5891/-4912), verdict recorded against the landed commit, findings
   filed as their own items rather than blocking. Costs one full review of a
   large diff and cannot gate anything, but does ask the quality question.
c. Close it `not-planned` with the evidence, on the grounds that the board
   never held authority over this change.

Apply the chosen option and end «ulrV_P24b».
