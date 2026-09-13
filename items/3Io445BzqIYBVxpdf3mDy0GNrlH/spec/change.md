Decide and act on one of:

a. remove the dead `#ifdef SQLITE_ENABLE_SESSION` code from
   `lsqlite3.c` entirely (and any `definitions.lua` rows/test
   fixtures that only exist to accommodate it), since nothing in this
   repo's build ever compiles it in;
b. keep it (e.g. because a downstream consumer or a future build
   variant is expected to enable `SQLITE_ENABLE_SESSION`), but make
   its dead status discoverable from the source itself — a comment
   at the top of the guarded block pointing at why it's there and
   that it is not compiled in today, not just a test-file comment a
   contributor has to stumble onto.

Whichever is chosen, `test_definitions_coverage.lua`'s exclusion
comment and `test_cosmo.lua`'s assertion should stay consistent with
the decision.
