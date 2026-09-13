- No binding change. `unix.execvp`/`execvpe`/`fexecve`/`daemon`'s
  signatures and return shapes are frozen.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not fold either file into `tool/lua/test_unix_proc.lua`. Each ports
  as its own file under its own stamp; the pre-existing
  `test_unix_proc.lua` is untouched by this slice.
