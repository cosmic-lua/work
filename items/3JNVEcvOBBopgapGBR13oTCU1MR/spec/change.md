`--make fmt` reports formatting mismatches and can only tell the caller, per
file, to go run `cosmic --fix` by hand. There is no bulk write mode
(`cosmic --make help` lists none), so the loop is: run the 4-9 minute gate,
read `ci: FAIL (fmt)`, fix, run it again.

Measured this session: `fmt` alone failed 3 of the 5 gate runs that failed at
all, across three separate items. Every failure was `<const>` spacing or a
continuation indent — mechanical, deterministic, exactly what `--fix` emits.
Roughly 15-25 minutes of wall clock and two extra full-suite runs for zero
information the formatter did not already have. On the fifth item I ran `--fix`
over the changed files BEFORE the gate and `fmt` passed first time; that is the
control.

Add `--make fmt --write`: the stage already enumerates every file and knows
which mismatch, so it fixes exactly that set and reports what it rewrote. The
default stays read-only, so `--make ci` is unchanged and still a gate.
