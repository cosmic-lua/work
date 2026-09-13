- Generalizing the rule to the equivalent fixed-triple failure helpers
  in other modules (`lre.c`, `lzip.c`, `lsqlite3.c`, `largon2.c`,
  `lpath.c`, if any exist) is a separate, later item — this one is
  `unix` / `LuaUnixSysretErrno` only.
- Adding `unix.tiocgwinsz`, `unix.nanosleep`, or any other binding to
  `test_definitions_conformance.lua`'s `PROBES` is not this item's job,
  and is likely not hermetically possible for these two specifically
  (see Change) — that file's growable coverage is a separate ratchet.
- Auditing or fixing every binding the scoping scan above turned up is
  not required: seeding the new allowlist for a non-trivial finding is
  an acceptable outcome of this PR, exactly like every other ratchet
  in this file when it was introduced.
- Not a defect in PR #335 or any single binding fix — those diffs are
  correct; this closes a gap in the harness meant to guard them.
