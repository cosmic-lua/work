- No binding change. `unix.setenv`/`unsetenv`/`clearenv`/`environ`'s
  signatures and return shapes are frozen.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not merge the three files; each is a distinct binding and stays
  under its own stamp.
