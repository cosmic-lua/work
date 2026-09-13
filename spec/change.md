Bump `cosmic-lua/cosmic`'s `bin/gitboard.pin` (url + sha256) to the
values quoted above — or whatever `cosmic-lua/work`'s current release
names if it has moved further ahead by the time this is built, the
same "parity, not this exact sha" rule `«HD1o_sZ5c»` used for the
symmetric bump on the other side. Run `bin/gitboard --help` (or any
read-only verb) once after the bump to confirm the new binary
downloads and its sha verifies.
