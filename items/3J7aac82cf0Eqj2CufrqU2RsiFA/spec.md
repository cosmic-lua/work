## Change

Ready when: `test -f _tool/surface.tl && echo READY` prints `READY`.

Add `_tool/surface_archive.tl` and `_tool/surface_archive_test.tl`, touching no
other product file. Export
`surface_of(path: string): Surface | nil, string`.

Open `path` with `cosmic.zip.open` in read mode, list entries, select only
`.tl/cosmic/**.tl`, strip the `.tl/` prefix to form the source-map key, read
each selected entry, close the archive on every success/failure path, and call
`_tool.surface.extract`. Missing embedded Cosmic Teal sources, list/read/close
failures, malformed ZIPs, and extraction failures return `nil, string` with the
path and failing operation. Never execute the archive.

Tests construct plain tiny ZIPs with `cosmic.zip`, covering successful source
collection, ignored entries, missing sources, malformed archives, and
propagated extraction errors. Keep the combined change between 160 and 240
lines.

## Non-goals

No executable fixture, self-binary lookup, comparison/rendering, CLI, network,
or project filesystem scan.

