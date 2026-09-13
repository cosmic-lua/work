`-DSQLITE_ENABLE_DESERIALIZE` on `lsqlite3.o` (`tool/net/BUILD.mk`) and
the extension registry stay. This is a flag removal, not a bump of the
vendored sqlite3.c.
