`done`'s landing-descent check refuses any completion whose claim base is an
unmerged branch commit, in a repository that squash-merges. That is now the
ordinary shape of every reworked item, because «Ge9j_2iCP» makes a rework's
claim base the handover commit itself.

`commit_evidence.verify_landing`, called from `_work/gitdone.tl`, asserts the
landed commit descends from the claim base. Under squash merge no branch
commit is ever an ancestor of `main`, so the assertion cannot hold.

Verified empirically during «Ge9j_2iCP»'s build with an isolated probe, on a
tree already carrying that item's fix. Build handover `H` off base `B`,
advance `main` past `H` with two unrelated sibling commits, then squash-merge
`H`'s content as a fresh commit parented on the advanced `main` — never on
`H`, which is exactly what a real squash merge produces. Then:

    commit_evidence.verify_landing(root, claim_base = H, accepted = H,
                                   landed = <squash commit>)
    -> refused: landed commit ... forks from <B>, which does not descend
       from claim base H

The mechanism: the merge-base of the accepted commit (a descendant of `H`)
and the landed commit is `B`, the common ancestor BEFORE `H`. `B` is never a
descendant of `H`, so `is_ancestor(H, fork)` is false. This is structural,
not a fixture artifact — it refuses for any claim whose base is a branch
commit, which «Ge9j_2iCP» now produces for every rework by design.

The observable cost, which «Ge9j_2iCP»'s own background section already
names: every reworked item in this repository needs `done --force --why` to
complete, and each forced completion is an audited escape recorded against
work that was in fact landed and verified. «Ge9j_2iCP» resolves its title
(the claim-side deadlock) but not that consequence.

Teach `verify_landing` the squash case. When the claim base is itself an
unmerged branch commit — not an ancestor of the landed commit's branch — the
descent check's premise does not hold, and the evidence that the work landed
has to come from somewhere else: the accepted commit's TREE appearing in the
landed commit, or the landed commit naming the PR whose head was the accepted
commit. Pick one and state why; do not simply drop the check, which is what
makes a forced completion auditable today.

Regression: an item completed through claim -> handover -> request changes ->
rework -> accept -> squash merge completes with a plain `done --landed`, no
`--force`. Assert the negative too: a landed commit that carries neither the
accepted tree nor any relation to the claim still refuses.
