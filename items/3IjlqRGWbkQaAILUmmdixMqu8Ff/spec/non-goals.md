- No change to `unix.Dir:read()`'s success-path four-value shape
  (`name, kind, ino, off`) — only the failure branch gains slots.
- No change to any other binding in this slice (`stat`, `fstat`,
  `statfs`, `fstatfs`, `opendir`, `fdopendir`, `Dir:close`, `Dir:fd`,
  `Dir:tell`, `tmpfd`) — all ten are tuple-exact already, per the
  parent census item's summary table.
- No change to the Windows (`readdir_nt`) or zip (`readdir_zipos`)
  branches' internal logic beyond whatever `errno` discipline the fix
  requires them to also observe — this item is about the Lua-boundary
  tuple, not a semantic change to directory iteration itself.
- No cosmic-side wrapper change in this item — that is a separate,
  dependent follow-up (see Change).
