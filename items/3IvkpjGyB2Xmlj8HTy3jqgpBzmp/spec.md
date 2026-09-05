## Goal

`cosmic` with no script argument and a piped (non-tty) stdin silently
drops into the line-by-line REPL instead of running the piped input as
one script — every `local` binding dies at the end of its own line, so
a multi-line heredoc produces a cascade of `attempt to index a nil
value` errors instead of running. There is no error message pointing
at the fix (`cosmic /dev/stdin <<EOF`); a script author gets wrong
output that looks like their own code is broken.

## Evidence

Measured directly against `./bin/cosmic` (this tree's binary, fetched
from the pinned release):

```
$ cat <<'EOF' | ./bin/cosmic
local sqlite = require("cosmic.sqlite")
local db = assert(sqlite.open("/home/user/work/o/board.db"))
local row = assert(db:query_one("SELECT COUNT(*) AS n FROM items"))
print(row.n)
assert(db:close())
EOF
Lua 5.5  Copyright (C) 1994-2024 Lua.org, PUC-Rio
Type help() for docs, or use --docs <query> outside the REPL
>:
>:
stdin:1: attempt to index a nil value (global 'sqlite')
...
```

Each piped line is compiled and run as its own chunk — the REPL's
prompt (`>: `) prints even though stdin is not a tty, so nothing
signals "this is not going where you think." The exact same script,
run via `/dev/stdin` as an explicit path instead of no path at all,
works correctly as one chunk:

```
$ ./bin/cosmic /dev/stdin <<'EOF'
... (identical body) ...
EOF
1045
```

Root cause, `cmd/cosmic/main.tl:486-489`:

```lua
-- Interactive mode or REPL
if opts.interactive or (#opts.execute == 0 and #opts.load == 0 and #arg == 0) then
  handlers.run_repl()
  return 0
end
```

`opts.interactive` (`-i`) is OR'd with "no script, no `-e`, no `-l`" —
so omitting a script path triggers the REPL exactly the same as `-i`
does, with no check anywhere in this branch (or in `run_repl` /
`cosmo.repl` per `_cli/main_handlers.tl:21-32`) for whether stdin is
actually a terminal. A user (or an agent following `AGENTS.md`'s own
`cosmic /dev/stdin <<EOF` guidance) who instead pipes without a path —
the more obvious-looking guess — hits this silently.

## Change

In `cmd/cosmic/main.tl`, split the REPL condition: `-i` always forces
`run_repl()` as it does today; the no-script/no-`-e`/no-`-l` case
instead checks whether stdin is a tty (`cosmo.unix.isatty(0)` or
equivalent already exposed per `cosmic --docs cosmo.unix`) and, when
it is NOT a tty, treats the missing script as `/dev/stdin` and falls
through to the existing `handlers.load_script_file`/`xpcall` path
above rather than calling `run_repl()` — reusing the code path this
item's own Evidence already proved correct, not writing a new one.
When stdin IS a tty (the normal interactive case), behavior is
unchanged. Add a case to whichever test file covers `cmd/cosmic/main.tl`'s
argument dispatch: piped non-tty stdin with no script argument runs as
a script and exits 0 with the expected output, not the REPL banner.

## Non-goals

Not changing `-i`'s behavior (always forces the REPL, tty or not) —
that stays a way to force interactive mode over a pipe if anyone
relies on it. Not touching `cosmo.repl`'s own line-by-line semantics
for the genuinely-interactive case.
