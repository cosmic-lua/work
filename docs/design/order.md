# Design — one tree, ranked at every level

gitboard orders a board of items by three mechanisms: a parent chain
that gives an item its context, a `beats` relation that ranks whatever
was compared, and a `blocked_by` relation that lifts a prerequisite to
where its waiter sits. Each is derived honestly, and together they
need seven position fields, five SQL views, a board-wide cycle walk,
and a doctrine page, a README section, a module header and a consumer
skill to say what "more important" means. This design collapses them
into one mechanism, stated once, that owes nothing to the project the
board happens to serve.

## The rule

An item's rank is a path: its root's rank among roots, then its rank
among its siblings at each level down. Rank among siblings is a
position in a list the parent holds; siblings not in the list follow
it, by age. A root not in the board's list, and everything under it,
is triage.

Everything below is that rule applied.

## The tree is the whole graph

There is one edge: parent. A parent with open children is a container
being decomposed; a parented item with none is workable; a root with
none is a capture awaiting triage. Nothing changes in that derivation.
What changes is that the two other edge kinds fold into it.

**A prerequisite is a child of the item that waits on it.** The waiter
has an open child, so it is a container and cannot be taken; when the
child resolves the waiter is a leaf again and pullable. The child
inherits the waiter's rank prefix, so it is ordered where the work it
gates is ordered, which is what the blocker lift computed. The
block-first exit from `doing` becomes: file the question as a child of
the stuck item, then release the claim. The reason a block carried is
the child's title and spec. A prerequisite two items wait on files
under the higher-ranked waiter, and the other waiter's spec names it.

**Importance is a position, not a relation.** The parent holds an
ordered list of child ids. `rank ID --before OTHER` (or `--after`, or
`--last`) edits that one blob on the parent's ref, the same one-item
write every verb makes. Transitivity is free, a cycle cannot be
written, and the placement procedure `compare` already prescribes
(walk down until it loses once, up until it wins once) is binary
insertion into a list. An item absent from its parent's list is
unranked among its siblings and sorts after every ranked one, oldest
first, so the forcing function `compare` had survives: to place
something you say where it goes among its peers.

**Roots are children of the board.** The root list lives at
`refs/heads/board/order`, beside `seq` and `format`. The derivation
has no root case: every item's parent holds its order, and the empty
parent's list is that ref. The one asymmetry is policy, not
derivation: a root must be ranked before anything under it is
pullable, because the top level is where the board's owner answers
"which of these outcomes matters more", and a capture filed as a root
has not been asked it. Below the top level the parent already
answered. That policy is the whole of what "triage" means. An
unranked non-root is therefore pullable: it sorts after its ranked
siblings, oldest first, and `take` never refuses it for lacking a
position.

## Moves and stale entries

`attach ID PARENT` re-parents one item, as today. Its position under
the old parent is meaningless once it has left, so the old parent's
list entry is ignored on read and reported by `fsck`; `attach` never
rewrites the old parent. The moved item arrives unranked among its
new siblings: the mover judged where it belongs, not how it compares
to neighbours it has never been weighed against. Moving between roots
is already the large rank change (a new prefix); one `rank` afterwards
refines. `attach` accepts `--before`/`--after` so a move that knows
its place lands in one commit on two refs; there is no separate
move-then-rank pair to run, and `rank` alone is the same-parent case.

A whole subtree moves with its container and keeps its internal order:
the container's own entry goes stale, its children's list is untouched.

## Verified outcomes are done roots

A root whose win condition holds is `done --reason completed --by
CHILD`, where CHILD is the verification item that carries the evidence:
a child of the root whose own resolution is `completed`. `done` refuses
a root with an open child, a CHILD that is not its completed child, or
no `--by` at all, so a root cannot be verified by assertion; the child's
id rides in the commit subject and the verdict line, so the log names
the evidence. Retiring a root needs no child: `done --reason
not-planned` asks only for the reason. Filing or attaching a
child under a done root clears its resolution in the same commit,
which is the hook that clears a held marker today (`gate.containered`
in `_work/gitgate.tl`), so evidence against an outcome reopens it with
no verb and no window. Intake skips done items already, so it skips a
verified root with no rule of its own. `show` still renders a done
root by id, since it is the record of what holds.

The held marker existed for two reasons that no longer hold: the
reopen it said would need a verb built from scratch is the same
child-filing hook, applied to `resolution` instead of `is_held`; and
`done`'s gates protect a PR-bearing leaf, which a root never is, so a
root's `done` asks for the evidence instead: the completed child named
by `--by`. The same filed child reopens a verified and a retired root
alike.

## The verb surface

| today | after | note |
|---|---|---|
| `compare A B` | `rank A --before B` | position, not relation; `--after`, `--last` |
| `block A --on B --reason` | `attach B A` or `new --parent A` | the prerequisite is a child |
| `unblock A B` | `attach B ELSEWHERE`, or `done B` | a child moves or ends |
| `hold R --reason` | `done R --reason completed --by CHILD` | verified by a completed child |
| `unhold R` | file the evidence as a child | the only reopen path |
| `attach ID PARENT` | same, plus `--before`/`--after` | move and place in one commit |

Nineteen verbs become sixteen. `take` refuses an item whose root is
unranked, as it refuses an unplaced one today. `next`'s triage rung
lists unranked roots. `show ID` prints rank as "3 of 7 under X", and
"unranked" where it is.

## Storage

An item's tree loses `edges/**` and the `held` marker and gains one
blob, `order`, holding child ids one per line, present only on a
parent that has ranked at least one child. `refs/heads/board/order`
holds the same blob for roots. `_work/itemtree.tl` stays the one
place the shape is written. The format marker bumps, and the
migration is one commit on the board: each `beats` closure becomes a
list under the common parent, each live `blocked_by` becomes a
re-parent (the blocker under its waiter), and the `held` marker is
dropped (no root carries one). The board's history keeps the old
edges readable.

Concurrency is unchanged in kind and simpler in count. A `rank` is a
commit on the parent's ref, pushed as the compare-and-swap every
mutation is; two sessions ranking under one parent race on that ref
and the loser re-runs against the merged list, as any lost race does.
No mutation needs the board-wide `seq` lease for ordering: the
parent's own tip is the lease, and `block`'s bounded add half, the
one ordering verb that read the whole board, no longer exists.

## What it drops

| concept | replaced by |
|---|---|
| `beats`, `compare`, the dominance count `own` | a position in the parent's list |
| `band` (nearest placed ancestor's count) | the rank path's prefix |
| `placed` as a separate flag | "the root is ranked" |
| `blocked_by`, `block_reason`, `block`, `unblock` | the prerequisite is a child |
| the lift (`lift_band`, `lift_own`, `lifted_from`) | prefix inheritance |
| `unblocks` as a tie-break | age; reintroduce only if the flow log shows starvation |
| the board-wide cycle walk and `cycle_problems` | nothing; a list cannot cycle |
| cross-subtree comparison | refused: "attach first" |
| `is_held`, `hold`, `unhold`, `flow.roots`' third return | a done root that a child reopens |
| the `has_edge`, `own`, `ancestors`, `band`, `unplaced` views | one rank-path view |
| the tournament vocabulary (bye, contested pairs, the re-rank PR) | `rank` between roots |
| any tier or kind among roots | roots; a consumer may group them in its own prose |
| `Position` (seven fields) | the rank path, nil when the root is unranked |

Kept as they are: the parent edge, the seeded per-session tie-break,
age as the last word, stage rank in `_work/flow.tl` (finishing before
starting is a different axis from importance), the spec bar, the
doing bound, and the review gate.

Not taken, and why: the lane-repair `key` and its bound exemption stay
because a red scheduled lane is a different kind of urgency from
importance and is already one field; `result` and `pr` as two
handover channels stay because a verdict already reads both; an
integer rank on the child was rejected because two sessions can
assign the same number and an insertion renumbers siblings across
many refs; a global priority scale was rejected because it is an
asserted number with no forcing function, and everything drifts to
the top of it.

## The description lives in one place

`gitboard help order` is the statement, and it is the three sentences
under "The rule" above. `_work/priority.tl`'s header says only that it
derives that page, and the README's ordering paragraphs shrink to one
sentence citing it. A consumer's own docs (a goals file, a skill, a
decision record) cite the page too and restate nothing.
`_work/doctrine_test.tl` already pins that every page renders; a
second test pins that the module header and the page agree on the
sentence.

## What a consumer sees

The board serves any project. What a project brings is its roots: the
outcomes its owner ranks, and prose elsewhere saying what each means.
The board derives nothing from that prose, and the tool has no word
for a goal, a tier, or an instrument; it has roots, and the owner's
ranking of them. For cosmic-lua/cosmic that prose is its goals file
and its decision records, which cite `help order` and retire their own
restatements of it (the paired-comparison tournament, the held
marker's record, the block-first edge) in the change that adopts this
design.

## Evidence

Read from the derived cache of one live board on 2026-09-05:

| fact | count |
|---|---|
| open items | 229: 14 roots, 163 at depth 1, 44 at depth 2, 8 at depth 3 |
| `beats` edges | 85: 9 between roots, 63 with a depth-1 winner |
| open depth-1 items carrying their own comparison | 18 of 163 |
| open roots that are not an outcome | 5 |
| live `blocked_by` edges (both ends open) | 26: 22 between siblings, 21 within one root |
| blockers with one open waiter | 22 of 24 |

Within a root, 18 comparisons over 163 items means the order inside a
band is mostly age already; a cross-subtree comparison today raises
the winner's count but never moves it out of its ancestor's band, so
refusing it loses no working behaviour; and nearly every blocker is a
sibling of what it blocks, which is a child that was filed beside its
parent.
