- No change to `LuaUnixIsatty`'s C implementation in this capture —
  see "2." above, explicitly deferred, not adopted.
- No change to any other binding.
- No change to `cosmic/tty.tl`'s `is_tty` — its `boolean` return type
  and `or false` guard already match the corrected annotation; nothing
  there needs to change.
