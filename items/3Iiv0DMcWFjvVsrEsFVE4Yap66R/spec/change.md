In `tool/net/lsqlite3.c`, change line 1782 from `free(buffer);` to
`sqlite3_free(buffer);`. Re-run the probe above (and a populated-DB
variant) to confirm no crash, and confirm the returned string content
is correct (a valid SQLite serialization) on a populated database,
plus that `nil` is returned (not "failed to serialize" masking a
crash) for a genuinely empty schema. `definitions.lua`'s declared type
(`string?`, one return value) is a separate, secondary gap — see
"Non-goals" — but should be corrected if this capture's PR touches
the doc comment anyway (`db_serialize`'s failure path returns TWO
values, `nil, "failed to serialize"`, which the current `@return`
line does not mention at all).
