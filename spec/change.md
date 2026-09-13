This capture is **blocked on `0YFj_out2`**
(`cosmo.unix: nanosleep's failure tuple shares slots with the EINTR
remaining-time success values`), the archetype item for this tuple-
deviation family, still in `building` state as of this writing. Do not
pick this item up before `0YFj_out2` lands.

Once `0YFj_out2` is done, read its final `## Change`/result for the
settled mechanism, then:

- If it settled on **arity separation**: change
  `LuaReRegexSearch`/`LuaReSearchImpl` in `tool/net/lre.c` (shared with
  `:search`, so land that C change once and it fixes both methods
  together — coordinate with whoever holds the `:search` capture so
  the C edit isn't duplicated) to return a genuinely separate error
  slot, and rewrite this binding's `definitions.lua` annotation
  (re-verify current line numbers first) to match. Run
  `make -j$(nproc) o//tool/lua/test`.
- If it settled on **documented union accepted as-is**: this binding's
  current annotation (quoted above) already carries that shape.
  Confirm it matches whatever canonical style `0YFj_out2` settled and
  align wording if it differs.

Either way, re-run the probe above and paste its output. If the
contract genuinely changes shape (the arity-separation branch), also
leave a note on this item naming `cosmic/re.tl:184-196` as the
cosmic-side site a follow-up item (filed separately, in the
`cosmic-lua/cosmic` repo) will need to simplify once the shared slot is
gone — do not make that edit here, since it is a different repo.
