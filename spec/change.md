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
