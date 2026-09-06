## Evidence

PR #1746 (board item `LVYj_DA0K`)'s `ci` check failed identically twice
(run 34036882731, attempts 1 and 2, ~40 minutes apart, same commit
`10cb2ffe`/merge-ref `358f1821`):

    cosmic/errno.tl:52:15: error: invalid key 'E' in record 'unix' of type unix
    cosmic/errno.tl:97:39: error: invalid key 'E' in record 'unix' of type unix
    make: _types/tlast_gen.tl: cannot build o/cosmic/errno.lua
    build: FAIL (generate failed)
    make: the converging build failed; this build ran under the tree's
    own o/bin/cosmic, which may not match this tree — `rm o/bin/cosmic`
    and re-run to rebuild from the pin
    ci: FAIL (build failed)

This is NOT a defect in that PR's diff (which bumps
`3p/cosmos/cosmos_pin.tl` to a release that genuinely adds `unix.E`).
The `ci` job's own log shows the root cause directly:

    Run actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
      key: o-Linux-.../f1fc7509...-358f1821ff39c79893d0bdb3ab4f359497dd93ac
      restore-keys: o-Linux-.../f1fc7509...-
    Cache hit for restore-key: o-Linux-.../f1fc7509...-a54649260e08226057722df5202e9cd0bff48eb3
    Cache restored from key: o-Linux-.../f1fc7509...-a54649260e08226057722df5202e9cd0bff48eb3

`.github/workflows/pr.yml`'s `ci` job caches `o` keyed by
`hashFiles('bin/cosmic.pin')` alone (lines 141/143):

    key: o-${{ runner.os }}-${{ github.workspace }}-${{ hashFiles('bin/cosmic.pin') }}-${{ github.sha }}
    restore-keys: |
      o-${{ runner.os }}-${{ github.workspace }}-${{ hashFiles('bin/cosmic.pin') }}-

The comment directly above this step (lines 130-133) already states the
INTENDED invariant: "a cache handed across a pin advance mixes
generations and crashes on any name only one side has. A pin bump is
exactly when the old names may die (D20's transition), so it starts
cold instead" — but the hash covers only `bin/cosmic.pin`, not
`3p/cosmos/cosmos_pin.tl` or `3p/tl/*_pin.tl`. When a PR bumps one of
those OTHER pins without touching `bin/cosmic.pin`, the cache key is
unchanged, so `restore-keys`' prefix match happily reuses a stale `o/`
(including `o/3p/cosmos`, the unpacked cosmos runtime + its
`definitions.lua`) saved from a commit with a DIFFERENT cosmos pin —
here, one that predates `unix.E`/`unix.SIG` existing upstream at all,
reproducing exactly "invalid key 'E' in record 'unix'".

`save-always` is unset (defaults `false`), so a failed job never
overwrites the stale entry — this repeats deterministically for any PR
whose `3p/*_pin.tl` bump lands while a stale same-`bin/cosmic.pin`-hash
cache entry exists, until an unrelated successful run happens to save a
fresh one under the exact key (not guaranteed, and didn't happen here
across two attempts).

## Change

`.github/workflows/pr.yml`: widen the `ci` job's cache `key` and
`restore-keys` to hash ALL of this project's pin files, not just
`bin/cosmic.pin` — e.g.:

    key: o-${{ runner.os }}-${{ github.workspace }}-${{ hashFiles('bin/cosmic.pin', '3p/**/*_pin.tl') }}-${{ github.sha }}
    restore-keys: |
      o-${{ runner.os }}-${{ github.workspace }}-${{ hashFiles('bin/cosmic.pin', '3p/**/*_pin.tl') }}-

Confirm `hashFiles('3p/**/*_pin.tl')` actually matches
`3p/cosmos/cosmos_pin.tl` and `3p/tl/tl_pin.tl` (or however they're
named/globbed today — read the current `3p/**/*_pin.tl` layout before
picking the glob) so a bump to EITHER busts the cache the same way a
`bin/cosmic.pin` bump already does.

## Non-goals

Not touching the `build`/`repro`/`smoke` lanes' own cache
configurations (if any) — this item fixes the `ci` job's cache key
specifically, the one this evidence traces the failure to. Not
attempting to purge the currently-stale cache entry directly (no tool
access to the Actions cache API) — the key-widening fix means this
exact stale entry's prefix will no longer be a `restore-keys` match
for any future run once this lands, which is sufficient; the old entry
ages out on its own (7-day GitHub Actions cache eviction).
