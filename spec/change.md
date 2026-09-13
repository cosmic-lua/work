Three files in **whilp/cosmopolitan**, on the designated branch. Nothing else
moves.

**1. `third_party/sqlite3/tclsqlite.h` — new file, a stub.** Header guard
`COSMOPOLITAN_THIRD_PARTY_SQLITE3_TCLSQLITE_H_` (the guard spelling
`third_party/sqlite3/extensions.h:1` uses, path-derived) plus a comment saying
what the file is for: the include in `sqlite3.c` sits under `#ifdef
SQLITE_TEST`, which is never defined here, so nothing compiles its contents, but
`mkdeps` scans textually and the path must resolve for the dependency graph to
build. No declarations, no vendored Tcl header. Use verbatim:

```c
#ifndef COSMOPOLITAN_THIRD_PARTY_SQLITE3_TCLSQLITE_H_
#define COSMOPOLITAN_THIRD_PARTY_SQLITE3_TCLSQLITE_H_
/* Placeholder for the Tcl test harness header, which this tree does not
   carry. third_party/sqlite3/sqlite3.c includes it under #ifdef
   SQLITE_TEST, which is never defined here, so no compiler ever reads it.
   build/bootstrap/mkdeps scans includes textually and does not evaluate
   #ifdef, so the path must still resolve against HDRS/SRCS/INCS or the
   whole o/$(MODE)/depend graph fails to build and every object loses its
   header prerequisites. Contents are deliberately empty. */
#endif /* COSMOPOLITAN_THIRD_PARTY_SQLITE3_TCLSQLITE_H_ */
```

**2. `third_party/sqlite3/qrf.h` — new file, a stub.** Same shape, guard
`COSMOPOLITAN_THIRD_PARTY_SQLITE3_QRF_H_`, comment naming its own reason: the
qrf sources are already inlined into `shell.c`, so the `#ifndef SQLITE_QRF_H`
fallback include below them can never fire, and only `mkdeps` ever reads the
path. Keep it under 15 lines and add no declarations — declaring anything risks
colliding with the inlined copy.

**3. `third_party/sqlite3/BUILD.mk:29-32` — list both.** Add
`third_party/sqlite3/qrf.h` and `third_party/sqlite3/tclsqlite.h` to
`THIRD_PARTY_SQLITE3_A_HDRS`, preserving the block's tab-and-backslash
continuation style with the backslashes aligned at column 64 as they are today,
and keeping the list alphabetical — which puts `qrf.h` first, before
`extensions.h`, and `tclsqlite.h` last, after `sqlite3ext.h`.
`THIRD_PARTY_SQLITE3_HDRS` at `:191` derives from the artifact lists by
`foreach` and needs no edit.

Note the `.ok` consequence at `BUILD.mk:53`
(`$(THIRD_PARTY_SQLITE3_A_HDRS:%=o/$(MODE)/%.ok)`): every listed header gets a
standalone compile check, so each stub must compile on its own. A guard-only
file does.
