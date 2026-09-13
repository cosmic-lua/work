Three `tool/net/definitions.lua` blocks declare a comma-separated success
list on the first `@return` line and then the error on its own line.
cosmic's generator splits that comma into slots, so the generated type
puts the error at slot 3 (mkstemp, wal_checkpoint) or slot 5 (Dir:read)
while the C pushes it at slot 2. Rewrite each block to one slot per
line, spelling slot 2 as a union of the success value and the error
string, exactly as `unix.tiocgwinsz` (definitions.lua:7469-7474) does
today and passes every gate with (no QALLOW entry names it):

- `definitions.lua:5281` (`unix.mkstemp`):
  `---@return integer|nil fd` / `---@return unix.MkstempPath|string path
  the created file's path on success, or the error string on failure`
  / `---@return unix.Errno? errno`.
- `definitions.lua:8054` (`unix.Dir:read`):
  `---@return string|nil name` / `---@return integer|string kind ... or
  the error string on failure` / `---@return integer|unix.Errno ino ...
  or the errno on failure` / `---@return integer off`. Keep the prose
  that end-of-stream is a bare `nil` (the `for` iterator relies on it).
- `definitions.lua:1052` (`lsqlite3.Database:wal_checkpoint`):
  `---@return integer|nil nlog` / `---@return integer|string nckpt ... or
  the error message on failure` / `---@return lsqlite3.ResultCode? errno`.

No whitespace around `|` and no dangling bar: checks 9 of
`tool/lua/test_definitions_coverage.lua` (#344/#346) refuse both.
Update the matching `lunix.c` shape comments (mkstemp `lunix.c:1805`,
Dir:read `lunix.c:4234`) only if their branch lines change meaning; the
count-level gate in `tool/lua/test_definitions_help.lua` needs neither.
