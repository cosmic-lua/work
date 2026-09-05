## Change

`_work/*.tl` reads every SQLite column with `row.x as string -- cast:
from any (sqlite row)`: 88 sites today (`grep -c "cast: from any
(sqlite row)" _work/*.tl`), growing with every view the read model
adds. `cosmic.sqlite` already exports the typed readers
`column_text`, `column_integer`, and `column_number` (fallible:
`value | nil, string`, narrowing with `is`, no cast). Rewrite each
site to call the reader for the column's declared type, handling the
nil arm the way the surrounding function already handles a failed
query (return `nil, err`, or skip the row where the loop already
tolerates a missing field); a column whose type the schema declares
NOT NULL still goes through the reader, since the checker cannot see
the schema. Where a function reads five or more columns of one row,
add a small local record and one constructor that reads them all, so
the call sites stay short. Measured after: the cast count in `_work`
is 0 for this class and `bin/cosmic --make ci` passes; put the
before/after grep in the PR.
