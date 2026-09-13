Not touching the `build`/`repro`/`smoke` lanes' own cache
configurations (if any) — this item fixes the `ci` job's cache key
specifically, the one this evidence traces the failure to. Not
attempting to purge the currently-stale cache entry directly (no tool
access to the Actions cache API) — the key-widening fix means this
exact stale entry's prefix will no longer be a `restore-keys` match
for any future run once this lands, which is sufficient; the old entry
ages out on its own (7-day GitHub Actions cache eviction).
