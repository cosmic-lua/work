# Design — one tree, ranked at every level

gitboard orders a board of items by one mechanism, stated once, that
owes nothing to the project the board serves.

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
none is a capture awaiting triage. Every role and every state derives
from that, and nothing else is recorded about how items relate.

**A prerequisite is a child of the item that waits on it.** The waiter
has an open child, so it is a container and cannot be taken; when the
child resolves the waiter is a leaf again and pullable. The child
inherits the waiter's rank prefix, so it is ordered where the work it
gates is ordered. A gap found mid-build is filed the same way: the
question becomes a child of the stuck item, and the claim is released;
the item waits on the answer, and the answer's `done` frees it with no
further verb. What the prerequisite is for is its title and spec. A
prerequisite two items wait on files under the higher-ranked waiter,
and the other waiter's spec names it.

**Importance is a position.** The parent holds an ordered list of
child ids. `rank ID --before OTHER` (or `--after`, or `--last`) edits
that one blob on the parent's ref, the same one-item write every verb
makes. Transitivity is free and a cycle cannot be written. Placing a
new item is binary insertion: walk down the list until it loses once,
up until it wins once. An item absent from its parent's list is
unranked among its siblings and sorts after every ranked one, oldest
first; it is still pullable, and `take` never refuses it for lacking a
position. To place something you say where it goes among its peers.

**Roots are children of the board.** The root list lives at
`refs/heads/board/order`, beside `seq` and `format`. The derivation
has no root case: every item's parent holds its order, and the empty
parent's list is that ref. The one asymmetry is policy, not
derivation: a root must be ranked before anything under it is
pullable, because the top level is where the board's owner answers
"which of these outcomes matters more", and a capture filed as a root
has not been asked it. Below the top level the parent already
answered. That policy is the whole of what "triage" means: `take`
refuses an item whose root is unranked, and `next`'s triage rung lists
unranked roots.

## Moves and stale entries

`attach ID PARENT` re-parents one item. Its position under the old
parent is meaningless once it has left, so the old parent's list entry
is ignored on read and reported by `fsck`; `attach` never rewrites the
old parent. The moved item arrives unranked among its new siblings:
the mover judged where it belongs, not how it compares to neighbours
it has never been weighed against. Moving between roots is already
the large rank change (a new prefix). `attach --before X` or
`--after X` moves and places in one commit on two refs, for a move
that knows its place; `rank` alone is the same-parent case.

A whole subtree moves with its container and keeps its internal order:
the container's own entry goes stale, its children's list is untouched.

## Verified outcomes are done roots

A root whose win condition holds is `done --reason completed --by
CHILD`, where CHILD is the verification item that carries the
evidence: a child of the root whose own resolution is `completed`.
`done` refuses a root with an open child, a CHILD that is not its
completed child, or no `--by` at all, so a root cannot be verified by
assertion; the child's id rides in the commit subject and the verdict
line, so the log names the evidence. Retiring a root needs no child:
`done --reason not-planned` asks only for the reason.

Filing or attaching a child under a done root clears its resolution in
the same commit (`gate.containered` in `_work/gitgate.tl`, the hook
that already clears a parent's claim and reviewer when it gains a
child), so evidence against an outcome reopens it with no verb and no
window, verified and retired roots alike. Intake skips done items, so
it skips a verified root with no rule of its own. `show ROOT` still
renders a done root, since it is the record of what holds.

## The verb surface

| verb | what it does |
|---|---|
| `new TITLE [--parent P] [--before X \| --after X]` | file an item, placed if the caller knows where |
| `attach ID PARENT [--before X \| --after X]` | re-parent, and place under the new parent in the same commit |
| `rank ID --before X \| --after X \| --last` | position among siblings; roots rank against roots |
| `done ID --reason completed --by CHILD` | on a root: verified by its completed child |
| `done ID --reason not-planned` | retire, root or not |

`show ID` prints rank as "3 of 7 under X", or "unranked". Sixteen
verbs in all: `init`, `new`, `attach`, `rank`, `set`, `spec`, `next`,
`brief`, `take`, `drop`, `verdict`, `done`, `show`, `sync`, `fsck`,
`find`.

## Storage

An item's tree carries its `meta` blob, its spec, and one optional
blob, `order`: child ids one per line, present only on a parent that
has ranked at least one child. `refs/heads/board/order` holds the same
blob for roots. `_work/itemtree.tl` is the one place the shape is
written.

A `rank` is a commit on the parent's ref, pushed as the
compare-and-swap every mutation is; two sessions ranking under one
parent race on that ref, and the loser re-runs against the merged
list, as any lost race does. No ordering verb needs the board-wide
`seq` lease: the parent's own tip is the lease.

## The order every queue renders

`_work/rank.tl` computes each item's rank path from the lists and
the parent chain, and `_work/flow.tl` sorts every queue by stage first
(finishing before starting: accepted, review, rework, building,
repair, todo) and rank path within a stage. The seeded per-session
tie-break replaces age among items nothing separates, so concurrent
sessions fan out across the tied remainder. The derived SQLite index
carries one rank-path view, and a stale list entry is visible only to
`fsck`.

## The description lives in one place

`gitboard help order` is the statement, and it is the three sentences
under "The rule" above. `_work/rank.tl`'s header says only that it
derives that page, and the README's ordering paragraph is one sentence
citing it. `_work/doctrine_test.tl` pins that every page renders, and
that the module header and the page agree on the sentence.

## What a consumer brings

The board serves any project. What a project brings is its roots: the
outcomes its owner ranks, and prose elsewhere saying what each means.
The board derives nothing from that prose, and the tool has no word
for a goal, a tier, or an instrument; it has roots, and the owner's
ranking of them. A consumer's own docs (a goals file, a skill, a
decision record) cite `help order` and restate nothing.
