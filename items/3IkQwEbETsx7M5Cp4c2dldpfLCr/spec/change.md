Two parts, one PR on cosmic-lua/cosmopolitan:

1. `tool/net/help.txt`: fix the `unix.getpgrp()` entry to the
   one-branch shape (`└─→ pgid:int`, no failure tuple), matching
   `tool/net/definitions.lua`.
2. A test beside the existing definitions ratchets in `tool/lua/`
   (`test_definitions_coverage.lua` is the model) that, for every
   `unix.*` function `help.txt` documents with a `├─→`/`└─→` shape
   block, compares the declared branch COUNT (one branch = infallible,
   two = fallible) against `definitions.lua`'s annotation for the same
   name (a `@return` admitting `nil` in slot 1 = fallible), and fails
   naming each mismatch. Count-level, not per-slot type: that is the
   drift these PRs actually produce, and it keeps the parser trivial.
   Enrol it in `tool/lua/BUILD.mk` like its siblings. Whatever the
   first run reports beyond getpgrp and the four bindings in
   `tpkl_saTa` becomes the fix list for this same PR, unless it exceeds
   a dozen entries — then land the gate with an explicit allowlist of
   the remaining names and file the rest as one follow-up item.
