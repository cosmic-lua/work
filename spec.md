## Change

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

## Non-goals

Mirroring entries into the SQLite cache, or any whole-board query over
them. `log ID` is a per-item read; a query that wants the cache arrives
with the query.

Any change to what existing verbs write into their own commit messages.
Their subjects and bodies stay exactly as they are.

A `--message` flag taking the text inline. An entry is prose, and prose
belongs in a file the author edited, the same way `spec ID FILE` takes
one.

Writing an entry as part of `take`, `verdict` or `done`. Those already
commit, and an entry that belongs to a state change rides that change's
own message.
