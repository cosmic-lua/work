Decide whether `third_party/lua/test/` in the fork is meant to be live, and
either make it so at 5.5 or delete it. It is currently neither: 41 tracked
files (33 `.lua`, 552K) of the upstream **Lua 5.4** test suite that nothing
runs, now one minor version behind the interpreter beside it.

Filed as a loose end of the 5.5 move (MuzfhbQP), which deliberately left it
alone rather than widening that change.
