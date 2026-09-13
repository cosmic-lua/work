`tool/lua/test_definitions_help.lua` (from #345) already parses
`├─→`/`└─→` blocks and compares branch-count fallibility against
`definitions.lua`. Extend it — or add a sibling
`tool/lua/test_definitions_lunix.lua` if the file's shape makes a second
source awkward — to read `third_party/lua/cosmo/lunix.c`'s
`// unix.<name>(...)` comment blocks with the same parser and apply the
same count-level comparison, failing by `lunix.c` line. Whatever the
first run reports becomes this PR's fix list (comment lines only, no C
code), unless it exceeds a dozen entries — then land the gate with an
explicit allowlist and file the rest as one follow-up. Enrol any new
test in `tool/lua/BUILD.mk` as a complete block with its own `@touch $@`.
