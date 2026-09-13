Bump `cosmic-lua/work`'s `bin/cosmic.pin` (url + sha256) to
`cosmic-lua/cosmic`'s current release, which carries the
`cosmic.ast`/`--find` chain — confirmed as of 2026-09-07 by reading
`cosmic-lua/cosmic`'s own `bin/cosmic.pin`:

    url = https://github.com/cosmic-lua/cosmic/releases/download/2026-09-07-2b2002d/cosmic-lua
    sha256 = b4bb8bde84fc54c4298e4d63d949a1af071d2ff5a2e1ba095fa70d9e342ee434

If `cosmic-lua/cosmic`'s pin has moved further ahead by the time this
is built, use whatever it currently names instead — the point is
parity with the tree's own pin, not this exact sha. Run `cosmic-lua/
work`'s own build/test entry point once after the bump to confirm the
tree still builds and its own test suite still passes against the new
pin.
