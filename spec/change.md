Needs a refiner: the fix is presumably swapping `%I` for the correct libc
format conversion matching `LUAI_UACINT`'s actual type (likely `%zu` or a
`PRI*`-style macro depending on how Cosmopolitan's fmt engine handles
`LUAI_UACINT`, which should be checked against its typedef), updating
`tool/net/definitions.lua`'s documented error string for `too_large` in the
same commit per this repo's binding-contract doctrine (the new AGENTS.md
bullet from `3IRIi0Dz`/PR #302), and a regression test pinning the byte
count actually appears in the message.
