Depends on the log reader (`gitboard log ID`). Once entries are
readable, they need a way in that does not require another mutation to
carry them.

The schema's rule is that content which is not prospective intent is a
log entry. Today an entry can only ride a commit some other verb was
already making, so an observation about an item — a measurement, a
finding, a correction to an earlier entry — has nowhere to go unless the
author also happens to be changing the item's spec or state.

1. `_work/gitlog.tl`: `log ID --add FILE` appends one entry. It writes a
   commit on the item's ref whose tree is IDENTICAL to its parent's —
   the entry is the message body, and nothing about the item changes.
   The subject names the verb and the item the way every other subject
   does (`note <id8> by <session>`); the body is `FILE` verbatim.
2. Its three wiring files, since this is a new option on an existing
   verb rather than a new verb: `_work/gitcommands.tl` (the option's
   declaration and help), `_work/gitboard.tl` (argv), `_work/gitverbs.tl`
   (the `cmd_log` entry, which gains the append branch).
3. `_work/fastimport.tl`: a tree-identical commit is a shape the stream
   writer does not emit today — every current mutation changes the tree.
   Confirm it round-trips through `gitboard fsck`'s re-encode audit,
   which compares a rebuilt tree sha to the observed one and is
   therefore satisfied by an unchanged tree, and add the fixture that
   proves it.
4. An entry is immutable. There is no edit and no delete: a correction
   is a new entry, which is how the corpus already worked when the
   sidecar carried this content (dated `## correction — …` headings
   appear in the spec churn).
5. **The append is fenced by the claim, like every other item-ref
   mutation.** `cmd_log_add` runs `gitclaimgate.mutation_refusal`
   before it writes, so a session that does not hold the item's claim
   is refused, and `log --add` carries `--force`/`--why` for the
   audited override every other fenced verb has. This was settled
   after a fresh-context review of the first landing (`request
   changes` at `6ed6b8dac`): an unfenced append let any session write
   a claimed ref, and because a note commit moves `items.touched_at`,
   keep a dead claim out of the `stale` view forever — an ungated
   `renew`. Fencing the ref closes both. `log` is also draftable and
   its help carries the prepares-only block, since `--add` prepares a
   mutation on a remote board.
