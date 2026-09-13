This capture is **blocked on `0YFj_out2`**
(`cosmo.unix: nanosleep's failure tuple shares slots with the EINTR
remaining-time success values`), the archetype item for this tuple-
deviation family, still in `building` state as of this writing. Do not
pick this item up before `0YFj_out2` lands — it is deciding the fix
mechanism for the whole family, and this capture must match whatever
it settles rather than invent an independent shape.

Once `0YFj_out2` is done, read its final `## Change`/result for the
settled mechanism, then:

- If it settled on **arity separation**: change `LuaReSearch` in
  `tool/net/lre.c` to return a genuinely separate error slot instead of
  reusing the captures-table position (for BOTH of its failure
  branches — compile failure and engine failure), and rewrite this
  binding's `definitions.lua` annotation (re-verify current line
  numbers first) to match. Run `make -j$(nproc) o//tool/lua/test`.
- If it settled on **documented union accepted as-is**: this binding's
  current annotation (quoted above) already carries that shape and
  prose, byte-identical to `re.Regex:search`'s. Confirm it still
  matches whatever canonical style `0YFj_out2` settled and align
  wording if it differs; otherwise close this item noting no change
  was needed beyond confirming conformance.

Either way, re-run the probe above (both failure branches, if you
extend it) against the freshly built binary and paste the output.
