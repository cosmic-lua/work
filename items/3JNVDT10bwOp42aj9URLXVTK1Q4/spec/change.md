Two `bin/cosmic --make` invocations running at once in the same working tree
corrupt the shared `o/` directory, and the failure names a file nobody touched.

Reported by a reviewer who started `--make ci` in the background and ran
`--make test` for a mutation check in the same tree. The background job died
with

    bytecode: /zip/_work/fixture.lua: /zip/_work/fixture.lua:223: ')' expected

a parse error in `_work/fixture.lua`, which neither invocation modified.
Recovery was `--make clean` plus a full re-run: ~10 minutes, ~6 tool calls, and
one wasted 9-minute gate. The reviewer's own diagnosis: the two runs raced on a
packed zip artifact under `o/`.

The danger is not the race but the symptom — it reads as a compiler bug in
unrelated code, so the next session debugs the wrong thing.

Take a lock. `--make` already owns `o/`; have it acquire an exclusive lock file
there (`o/.make.lock`) for the duration of a run and refuse a second
invocation in the same root with a message that says so plainly — naming the
running verb and its pid — rather than letting the two interleave.

Regression: a test that holds the lock and asserts a second `--make` in the
same root refuses with that message rather than proceeding.
