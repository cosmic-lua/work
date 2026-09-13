No write path, no claim verb, no fsck: the branch exists in tests only
until the migration. `store.read` (the cache) is not restructured — it
takes the digest and the Board from the reader as it does today.
