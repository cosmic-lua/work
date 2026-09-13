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
