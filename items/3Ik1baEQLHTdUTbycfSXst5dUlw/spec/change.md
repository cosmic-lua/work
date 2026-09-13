Apply the same bundling fix `unix.nanosleep` received: change
`unix.mkstemp`'s success return from two positional values `(fd, path)`
to a shape where slot 2 is never anything but the error string on
failure — e.g. `(fd, {path = path})`, or fold `path` into a record
alongside `fd` the same way `nanosleep`'s remaining-time table does.
Update `tool/net/definitions.lua`'s annotation for `unix.mkstemp` to
match in the same commit (this repo's AGENTS.md binding-contract rule:
"a deliberate contract change needs a matching `definitions.lua` update
here ... landed as its own change, never inside an optimization").

Downstream (cosmic-lua/cosmic, NOT part of this capture): the three
call sites above will need their destructuring updated once cosmic
bumps its cosmos pin to a release carrying this fix — flag it as a
consequence, do not fix it here.
