One row in AGENTS.md's mapping table:
`| cosmo.unix.chmod(p, m) | require("cosmic.fs").chmod(p, m) |`
becomes
`| cosmo.unix.chmod(p, m) | require("cosmic.fs").set_mode(p, m) |`.

Verified 2026-08-27: `cosmic/fs/init.tl:149,283` export `set_mode`;
no `fs.chmod` exists. The `unix.chmod` calls inside `cosmic/fs/*`
are the C-binding side of the wrappers and stay.
