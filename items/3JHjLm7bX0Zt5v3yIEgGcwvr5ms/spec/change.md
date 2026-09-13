`gitboard migrate6 [--dir] [--execute] [--frozen] [--limit N] [--catch-up]`:
build `refs/heads/state` from the format-5 refs and push it, as
`docs/design/storage.md` `## The migration` specifies. Wiring:
`_work/gitcommands.tl` (the declaration), `_work/gitboard.tl` (the
dispatch branch), `_work/gitmigrate6.tl` (the transform),
`_work/gitmigrate6_cli.tl` (the verb and the pushes).

**Freeze first.** `--execute` refuses without `--frozen`, the operator's
assertion that the GitHub ruleset refusing creation, update and deletion
under `refs/heads/items/**`, `ended/**`, `claim-batches/**` and
`board/seq`, with an empty bypass list, is in place; the refusal prints
that requirement verbatim.

**Checkpoint.** The run fetches, then writes `o/migrate6/checkpoint.literal`
(a `cosmic.literal` record through `_work/singlehead_literal.tl`): the
complete source ref set — every `items/*`, `ended/*`, `claim-batches/*`
and `board/*` name with its tip — the transform version, and after the
replay the marks and the replayed head. A rerun with a checkpoint
present replays from it and reports `identical` when the tree ids match;
a source ref that moved, appeared or vanished since the checkpoint is
named and the run refuses rather than resampling.

**The transform.** Every commit of every `items/*` and `ended/*` ref,
merged across refs by committer date with each ref's own first-parent
order preserved (ties fall to the ref name), into ONE fast-import stream
on `refs/heads/state` whose first commit carries `format`: message,
author, committer and dates exact; the item's tree grafted under
`items/<id>/` (`M 040000 <tree> items/<id>`) with `claim_batch` removed
from `meta`; a claim bridge (`Op: claim-bridge`, `grep -n '"claim-bridge"'
_work/gitclaim.tl`) replayed as the item tree it carries plus the
`claims/<id>` write its batch's acquisition/renew/drop means, the lease's
`id` being the acquisition batch commit (`_work/claimbatch.tl`'s `root`,
`grep -n "root: string" _work/claimbatch.tl`); a commit whose grafted
subtree equals its parent's (format 5's `Op: log` entry, or any other
tree-identical event) materialised as `items/<id>/log/<ksuid>.md`
carrying the body; every graft carrying the item's existing `log/`
entries forward. `--export-marks` is decoded into the tree as
`migration/marks` (`boardtree.encode_marks`), and a final commit
rewrites every `result`, `verdict_head` and `landed_head` naming a
replayed commit through it and writes every item's current lease —
active, or expired but not dropped — as `claims/<id>`.

**The pushes.** `--execute` pushes ancestors of the tip in turn — `git
push <remote> <sha>:refs/heads/state` every `--limit N` commits (default
2000), each fast-forward, idempotent on rerun — then refetches and
compares the complete source ref set against the checkpoint, refusing on
any moved, added or removed ref; only then the activation push, `--atomic`
over the tip and `refs/heads/board/format` → `6`. A dry run prints the
ref-set size, commit count, chain length, lease count, and the pushes it
would make. `fsck` on a format-6 board with a checkpoint beside it
compares the old tracking refs against the checkpoint's set and reports
drift; `--catch-up` replays a drifted ref through the same marks only
while `state` carries no native write past the activation commit, and
refuses otherwise naming the ref.

The PR evidence is a dry run against a clone of the live board (`git
clone --no-checkout https://github.com/cosmic-lua/work`), pasted: the
counts, the first and last three pushes, and the refusal without
`--frozen`.
