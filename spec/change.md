`third_party/sqlite3/update.sh`: after refreshing `shell.c`, extract
every registry unit from its `shell.c` section by the same rule the
test applies (section bounds, `sqlite3ext.h` include rewritten to the
repo path, the `u8` typedef restored where the shell inliner removed
it), driven by the registry's name list so a new batch needs no
script edit; a `README.cosmo` note names the rule. A dry run on the
current tree must produce byte-identical units.
