This capture is **blocked on `0YFj_out2`**
(`cosmo.unix: nanosleep's failure tuple shares slots with the EINTR
remaining-time success values`), the archetype item for this exact
tuple-deviation family, still in `building` state as of this writing.
Do not pick this item up before `0YFj_out2` lands — it is deciding the
fix mechanism (either a C-level return-arity change so no slot is
reused across success/failure, or a decision that documented-union is
an accepted exception) for the whole family, and this capture must
match whatever it settles rather than invent an independent shape.

Once `0YFj_out2` is done, read its final `## Change`/result for the
settled mechanism, then:

- If it settled on **arity separation** (a genuinely separate trailing
  slot for the error, never overlapping a real success value): change
  `LuaReRegexSearch`/`LuaReSearchImpl` in `tool/net/lre.c` to return a
  distinct extra slot for the error string rather than reusing the
  captures-table position, and rewrite the `definitions.lua` annotation
  above (re-verify its current line numbers first) to declare the new,
  non-overlapping shape. Run `make -j$(nproc) o//tool/lua/test`.
- If it settled on **documented union accepted as-is**: this binding's
  current annotation (quoted above) already carries that shape and
  prose. Verify it matches whatever canonical phrasing/style
  `0YFj_out2` established (e.g. does it want the prose to explicitly
  name the failure tuple the way the `unix.openpty` fix did?) and bring
  it into alignment if the wording differs; otherwise close this item
  noting no change was needed beyond confirming conformance.

Either way, re-run the probe above against the freshly built binary
and paste its output.
