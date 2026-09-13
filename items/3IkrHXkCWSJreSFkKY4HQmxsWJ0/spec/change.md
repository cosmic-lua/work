`tool/lua/test_definitions_help.lua`: extend the signature pattern the
parser accepts to `unix.<Type>:<method>(` in both sources (help.txt and
lunix.c), looking the block up as `function unix.<Type>:<method>(` in
`definitions.lua`, with the same count-level fallibility comparison
and the same by-line failure. Every block whose first line starts with
`// uni` but is not `// unix.` is a failure by line (so the two typos
are caught, not skipped). Whatever the first run reports becomes this
PR's fix list (comment lines only, the two typos included), unless it
exceeds a dozen entries — then land the gate with an explicit
allowlist and file the rest as one follow-up. `tool/lua/BUILD.mk`'s
rule keeps its `@touch $@`.
