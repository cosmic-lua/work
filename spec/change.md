`_types/tlast.tl`: replace `child.run` in `dump_via_base` with
`os.execute` over an argv-quoted command — `DUMPER`, `prog`, `srcfile`,
`out` are all paths the function itself created under `dest`, none
user-supplied, so shell quoting is a fixed `"%q"`-style wrap of four
known strings; success is `os.execute` returning `true`. Chosen over
moving the dump into `types_gen`'s phase because that phase's closure
is also exposed and the dumper is `o/3p/cosmos/lua` either way; chosen
over raw `cosmo.unix` fork/exec because that reintroduces the very
bindings (#340 wait, #328 pipe) whose shape is changing. Drop the
`cosmic.child` require; keep `cosmic.fs` (its `temp_dir`/`write`/`read`
are unchanged bindings on the read/write path this function needs).

Re-run the closure walk in the PR description to show `cosmic/child/*`,
`cosmic/fd.tl`, `cosmic/poll.tl`, `cosmic/stream.tl`, `cosmic/time.tl`
left the closure. `_types/tlast_test.tl` already calls `generate`
directly; it stays the proof that the dump still yields loadable
bytecode.
