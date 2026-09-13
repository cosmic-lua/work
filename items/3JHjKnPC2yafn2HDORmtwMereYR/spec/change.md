Write `docs/decisions/d50-one-branch-is-the-board.md` under the `decide`
skill's form (`skills/decide/SKILL.md`): H1 `# D50 — one branch is the
board`, date 2026-09, status active, then context, decision, rejected,
consequences. Regenerate the index with `bin/cosmic _docs/derive.tl` and
pass `bin/cosmic --make test _build/docs_test.tl _build/doc_paths_test.tl`
(the second checks every backticked `_work/` span names a file on
`refs/remotes/work/main`; a `sha:path` span is not checked — D49 line 29 is
the precedent).

**context** — the board is 3665 refs in a clone (707 `items/*`, 723
`ended/*`, 515 `claim-batches/*`), a whole-board write is a multi-ref push,
the session egress proxy refuses a receive-pack above ~50 ref updates (D49
measured it: 1, 10, 50 pass, 100 fail), 29 `_work/` modules are bound to
the ref layout, and cosmic-lua/work#167 added a second transport that
archives the layout as base64 packs inside one branch so a connector-only
environment can write at all — two transports for one board. The design
with the numbers is cosmic-lua/work's `docs/design/storage.md`; quote its
ref counts, do not re-derive them.

**decision** — a board is one branch (`refs/heads/state` on the board
repository) whose tree holds every item as files under `items/<id>/`, the
live leases under `claims/<id>`, and the format marker; a mutation is one
commit on it; the write fence is the object id of each touched path at the
staging base, re-checked at publish against the fetched head, so disjoint
writers rebase past each other and a same-path writer loses the race; a
publish is one non-forced push of that one ref, and a connector-only
environment reproduces exactly that push with `create_tree`,
`create_commit` and `update_ref(force = false)`. Sub-bullets for the parts.

**rejected**, each with the reason it lost — (a) keeping the ref-per-item
layout and batching every large write (D49): batching is a workaround for
a cap the layout walks into, and it leaves the connector path needing its
own transport; (b) the envelope of packs (work#167) as the durable format:
every reader base64-decodes and unpacks before it can read, packs and the
whole-blob manifest grow with every publication until compaction exists,
GitHub cannot show an item's history, and an opaque pack means two writers
can never merge, so every lost race is a re-executed call sequence; (c) a
database file committed on a branch (one SQLite blob): a binary blob merges
never, every write conflicts with every other, and the history of one item
is unreadable without the tool; (d) one file per item on a branch but
history only in the file (an append-only log inside `meta`): loses the
commit-per-mutation the events table and the flow measurements read.

**consequences** — enables: one-ref publish under any proxy, git-level
rebase of disjoint writers, a fresh reader that is a plain clone, GitHub's
UI as an item browser, one transport for shell git and the connector; costs:
every write serializes on one head (a `_perf` contention scenario is a
child of the plan; the number is what would make us revisit), a full
rebuild of the read model walks the branch's history (31618 commits at the
cutover), the branch is named `state` rather than `board` because `board/`
is an occupied ref directory until the old refs are deleted, and the
cutover is a one-way migration with a format marker that darkens every
unpinned clone at once; forbids: a second ref namespace for any board fact,
and force-pushing `state` (branch protection is the board owner's step).

Amend D49 (`docs/decisions/d49-board-rewrite-pushes-in-idempotent-batches.md`):
status `amended 2026-09 (one branch — D50)` and a trailing
`- **amended 2026-09 (one branch — D50):**` bullet saying that the
multi-ref push the batches were for no longer exists once D50's cutover
lands; the discipline survives as the size-bounded ancestor pushes the
migration itself makes.
