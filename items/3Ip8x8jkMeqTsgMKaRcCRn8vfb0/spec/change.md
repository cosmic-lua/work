#373 removed every session/changeset/rebaser binding from
`tool/net/lsqlite3.c`, and nothing else in the tree ever called that
API, but the amalgamation is still compiled with it enabled. Remove:

- `third_party/sqlite3/BUILD.mk:166-167`: the two lines
  `-DSQLITE_ENABLE_PREUPDATE_HOOK` and `-DSQLITE_ENABLE_SESSION` from
  `THIRD_PARTY_SQLITE3_FLAGS`. Both go together: the session extension
  is the only consumer of the preupdate hook (41 `#ifdef
  SQLITE_ENABLE_PREUPDATE_HOOK` sites in sqlite3.c, all session or
  pre-update plumbing).
- `tool/net/definitions.lua:523`: the comment line
  `-- Session / Changeset Constants` that heads nothing (the `SC()`
  rows under it left with #373); delete it and the blank line above so
  `CHECKPOINT_TRUNCATE = nil,` is followed directly by `}`.
- `tool/lua/test_cosmo.lua:104-106`: the comment now says the flag
  "was never defined for lsqlite3.o"; make it say the library flag is
  gone too, and keep the `db.create_session == nil` assertion at `:113`
  as the gate that the surface stays absent.

`shell.c` is in `THIRD_PARTY_SQLITE3_A_SRCS` (`BUILD.mk:59-60`) and
guards its `.session` command with `#if defined(SQLITE_ENABLE_SESSION)`
(7 sites); it compiles either way. Run `make -j o//tool/lua/test` and
`make -j o//third_party/sqlite3` (the shell package) before opening the PR.
