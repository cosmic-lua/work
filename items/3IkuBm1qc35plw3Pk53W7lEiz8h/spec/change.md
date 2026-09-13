`tool/lua/test_definitions_help.lua`: two guards, either of which
closes the silent drop —

1. A malformed-block failure: a line starting with the shape glyphs
   (`├─→`, `└─→`, `│`) whose indent does not match the open block (or
   that follows no open block) is a failure by file:line, not a skip.
2. A per-source floor pinned at the current count (`123` for help.txt,
   `158` for lunix.c at #347's head), raised in the same commit that
   adds blocks, so a vanished block fails the gate by count.

Do (1); do (2) as well if it costs one line. Both sources. The counts
the gate prints stay as they are.
