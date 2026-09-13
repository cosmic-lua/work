Write `docs/design/storage.md`: the design record for format 6, one branch
is the board, in the shape `docs/design/schema.md` has — an H1
`# Design — one branch is the board`, a one-paragraph rule, then the
sections below with the measurements pasted, not summarised. Add one line
to `README.md` directly under the paragraph that begins `An opt-in
\`gitboard single-head\` proof of concept` (`grep -n "single-head. proof of
concept" README.md`) naming the design as the planned replacement of both
transports. Nothing else in the tree changes.

`## The rule` — a board is one branch, `refs/heads/state` on
cosmic-lua/work. Its tree is the board's state; its first-parent history is
every mutation in the order it was published; one non-forced push of that
one ref is the only write.

`## What the ref layout costs` — the measurements, taken from a clone of the
live board on 2026-09-13 and re-taken by the builder (paste the commands and
their output): `git for-each-ref | wc -l` (3665), `refs/remotes/origin/items`
(707), `ended` (723), `claim-batches` (515), `git count-objects -vH`
(size-pack 20.03 MiB), `git rev-list --count --all` (31618). Then the
three costs, each with its evidence: (1) a whole-board write is a multi-ref
push and the session egress proxy refuses a receive-pack above ~50 ref
updates — cosmic's D49 records the 31-batch migration that cost, so the
one-ref write dissolves it; (2) 29 modules under `_work/` are bound to the
ref layout — paste `grep -lE 'refs/heads/items|for_each_ref|claim-batches'
_work/*.tl | grep -v _test | wc -l` and the list; (3) work#167's single-head
transport exists only because a multi-ref push cannot be expressed as
connector calls, and it preserves the layout by archiving packs inside one
branch, which every reader must unpack and GitHub cannot show.

`## The tree` — the exact layout, as a fenced tree:

```
format                    "6\n" — the marker `_work/format.tl` reads
items/<id>/meta           the format-5 meta lines, minus `claim_batch`
items/<id>/spec/change.md
items/<id>/spec/non-goals.md
items/<id>/order          present only when this item ranks a child
items/<id>/edges/<kind>/<id>
items/<id>/log/<ksuid>.md an appended entry (`log ID --add FILE`)
claims/<id>               the live lease: holder, acquired, renewed,
                          expires, product_base — one `key: value` per line
```

State the invariants: the item tree under `items/<id>/` is byte-identical
to `_work/itemtree.tl`'s `build_tree` output for that item (`grep -n "local
function build_tree" _work/itemtree.tl`), so the item codec is reused, not
rewritten; `claims/<id>` exists exactly while a lease is live and carries
the fields of `_work/claim.tl`'s `State` (`grep -n "local record State"
_work/claim.tl`) minus `control`, which becomes the commit that last wrote
the blob; the branch name is `state` because `board/` and `items/` are
already ref directories in every clone and a ref cannot be both a file and
a directory until those are deleted.

`## One commit, one mutation` — a mutation is one commit whose parent is
the staging base (the fetched `refs/remotes/<remote>/state`), author the
session, committer gitboard, subject the existing verb grammar
(`_work/events.tl`'s `parse_subject`, `grep -n "local function
parse_subject" _work/events.tl`), `Op:` trailer as today. A `log --add`
entry writes `items/<id>/log/<ksuid>.md` and carries the same text in the
commit body, so both `git log -- items/<id>` and the tree show it. A claim
batch is one commit writing every member's `claims/<id>`; renew rewrites
them; drop deletes them. There is no `board/seq`: the branch's first-parent
order is the sequence.

`## The write fence` — the lease is the object id of each touched path at
the base: `items/<id>` (the subtree) and `claims/<id>` (the blob). At
publish, with the fetched head H and base B: if H equals B, push; otherwise
for every touched path compare its object id at B and at H — all equal
means rebase the commit onto H (`git cherry-pick`-shaped: re-apply the same
tree changes over H's tree) and push; any difference is `LOST_RACE`, the
same refusal `_work/publish.tl` returns today (`grep -n "LOST_RACE"
_work/publish.tl`), and the verb re-reads. A non-fast-forward rejection at
the push is a moved head: fetch and repeat, at most five times, then refuse.
Say why this is strictly better than the ref-per-item fence: disjoint
writers never wait on each other, the same-item writer still loses, and
the retry is a local rebase rather than a fresh prepared transaction.

`## Reading` — the read model (`docs/design/read.md`) rebuilds when
`refs/remotes/<remote>/state` differs from the sha `cache_meta` recorded;
items come from one `git ls-tree -r` and one `cat-file --batch`; each
item's `tip` and `touched_at` and the `events` rows come from one
`git log --first-parent --format=%H%x00%ct%x00%an <%ae>%x00%s --name-only`
walk of the branch, the first commit naming a path under `items/<id>/`
being that item's tip. State the cost honestly: a full rebuild walks every
commit on the branch (31618 today) and the incremental patch on save and
fetch reads only the commits between the recorded sha and the head.

`## Drafts and prepared transactions` — a prepared transaction is a local
ref `refs/gitboard/prepared/<id>` naming the staged commit, its base the
commit's parent; a draft is `refs/gitboard/draft/<id>`, a chain of staged
commits from one snapshot, published by rebasing the chain onto the head
and pushing it whole — every mutation stays its own commit. `refresh`
confirms a transaction when its pushed commit is an ancestor of the fetched
head and retires the local ref.

`## A connector-only environment` — the plan is `{head, changes, message}`
where a change is `{path, mode, content | delete}`; the calls are
`create_tree(base_tree = head's tree)`, `create_commit(parents = [head])`,
`update_ref(force = false)`. No packs, no hydration: the fence above is the
same check run in Teal against the fetched head before the calls are
rendered.

`## The migration` — replay every item ref's first-parent chain, every
commit, in committer-date order into one `git fast-import` stream
(`_work/fastimport.tl`) producing `state`: message, author and dates
preserved, tree the item's tree under `items/<id>/`, a claim bridge
(`Op: claim-bridge`, `grep -n '"claim-bridge"' _work/gitclaim.tl`) replayed
as the item tree it carries; then each item's currently ACTIVE lease
written once as `claims/<id>` in a final commit. The push is one ref but may
exceed what the proxy accepts in one body: push ancestors of the tip in
turn (`git push origin <sha>:refs/heads/state`, each fast-forward,
idempotent on rerun — D49's discipline applied to size), and the last push
carries `refs/heads/board/format` → `6` atomically with the tip, so a
format-5 binary refuses the board from that moment and a format-6 binary
reads it.

`## Plan` — the numbered list of children under the container, in landing
order, one line each: boardtree codec; reader; writer and prepared
transactions; claims as files; drafts and log entries; fsck and init;
migrate6; release and pin bump; run the migration; retire; connector plan;
contention scenario. State the two orderings that are load-bearing (reader
before writer before cutover; migration, release and pin back to back) and
that retire waits for a confirmed live board.
