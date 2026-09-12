## Change

The schema moves everything retrospective — what was measured, what was
found, what happened along the way — into commit message bodies on an
item's own ref. Nothing reads a commit body, and there is no verb that
shows one:

```
$ grep -rn '"log"\|log_entries\|commit_body' _work/gitcommands.tl \
    _work/gitverbs.tl _work/gitread.tl
(no output)
$ grep -n 'cat-file\|rev-list\|log' _work/gitread.tl
401:    local r = child.run({"git", "cat-file", "-p", object .. ":spec.md"}, …
412:--- `cat-file --batch` instead of one process per item.
```

`_work/gitread.tl` reads trees and blobs and never a commit's message.
So the migration would write 28% of the board's prose into a place no
verb can show, which is the one ordering that must not happen: build the
reader first, then move the content.

1. `_work/gitread.tl`: add a history reader beside `read_spec` — one
   `git log --format=<...>` per ref yielding, oldest first, each commit's
   sha, committer date, author identity, subject and body. Batch the
   whole-board form the way `read_specs` batches blobs, so a board-wide
   read stays one process rather than one per item.
2. `_work/gitlog.tl` (new): the `log ID` verb. Renders an item's entries
   newest first — date, author, subject, then the body indented — and
   `--oneline` for subjects only. An entry with an empty body prints its
   subject alone, which is what every commit on the board carries today.
3. Its three wiring files: `_work/gitcommands.tl` (the declaration and
   its options), `_work/gitboard.tl` (the argv dispatch branch),
   `_work/gitverbs.tl` (the `cmd_log` entry).
4. `_work/gitshow.tl`: render the item's **outcome** — the body of the
   commit that set `resolution`, or of the latest handover commit while
   the item is open — under its own marker, the way the spec sidecar is
   rendered under `--- spec ---` today (`grep -n 'spec ---' _work/gitshow.tl`).
   An item whose commits carry no body prints no such block, so nothing
   changes for the board as it stands.

## Non-goals

Appending an entry. A verb that records a log entry without otherwise
mutating the item is its own item; this one makes what the migration
writes readable, which is what the migration is blocked on. Every entry
the migration writes rides a commit it was already making.

Mirroring the log into the SQLite cache. `log ID` and `show ID` are
per-item reads, so neither needs it; a whole-board query over entries
does, and that arrives with the query that wants it.

Changing what any existing verb writes into a commit message. The
subjects stay exactly as they are (`spec <id>`, `take <id> by <id>`);
this reads bodies that are empty today and will not be after the
migration.

`spec.revision`, the path parsers, and the `## Acceptance` readers: all
retirement work, and all of it later.
