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

Carving note commits out of `touched_at`. The holder's own notes
advancing the freshness clock is correct — the holder is active — and
the freshness digest is one `for-each-ref` that cannot see a subject;
teaching it to would put a per-commit read on the whole-board path, and
any carve-out would have to hold identically in the cache patch and the
rebuild or `fsck` goes red. The fence makes the carve-out unnecessary.
