Redeclare `re.Regex:search`'s return shape so no slot serves two
purposes — e.g. split into an explicit outcome type/record, or move
the error string off slot 2 (mirroring whatever shape
`unix.nanosleep`'s companion capture settles on for its own
deviation). Update `definitions.lua`'s annotation and the C-side
comment together; a shape change here is a `LuaReSearchImpl` change,
so it also touches `re.Regex:match` and `re.search` — a single diff
is likely to resolve all three plus `re.Regex:find`'s analogous
capture, but each is filed separately per this census's
one-capture-per-binding rule; do not let filing granularity imply
four independent fixes are required.
