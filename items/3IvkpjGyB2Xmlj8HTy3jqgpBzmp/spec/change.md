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
