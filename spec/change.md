Land the 13 real units in three PRs, alphabetical, sizes 5/5/3 (13
does not divide evenly into three fives), each against `master` of
cosmic-lua/cosmopolitan and each green on `make -j$(nproc)
o//tool/lua/test` with the size delta in the PR body:

- Batch 1 (5): `appendvfs base64 base85 completion dbdata`
- Batch 2 (5): `decimal fileio ieee sha shathree`
- Batch 3 (3): `sqlar stmtrand uint`

`fileio` is extracted like the rest and registers nothing; its
default availability is the cosmic API item's decision.

Batch 2's PR must also add a marker-stem override to
`tool/lua/test_sqlite_extensions.lua`, parallel to `FROM_SRC_TREE`
but for "registry name differs from shell.c stem" rather than "not
shell.c at all" — e.g. `local MARKER_STEM = { ieee = "ieee754", sha =
"sha1" }` consulted where the marker string is built (around line
139: `local stem = MARKER_STEM[name] or name`), leaving every other
unit's marker-matching, including the byte-for-byte inlined-copy
assertion, unchanged.
