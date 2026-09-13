This capture is **blocked on `0YFj_out2`**
(`cosmo.unix: nanosleep's failure tuple shares slots with the EINTR
remaining-time success values`), the archetype item for this tuple-
deviation family, still in `building` state as of this writing. Do not
pick this item up before `0YFj_out2` lands.

Once `0YFj_out2` is done, read its final `## Change`/result for the
settled mechanism, then:

- If it settled on **arity separation**: change `LuaReRegexFind`/
  `LuaReFindImpl` in `tool/net/lre.c` to return a genuinely separate
  error slot rather than reusing `stop`, and rewrite this binding's
  `definitions.lua` annotation (re-verify current line numbers first)
  to declare the new, non-overlapping shape — bring it to whatever
  prose style the settled family convention uses (matching the fuller
  `:search`/`:match` block style, if that's what won). Run
  `make -j$(nproc) o//tool/lua/test`.
- If it settled on **documented union accepted as-is**: decide whether
  this binding's terser inline-parenthetical style needs to be brought
  up to the fuller prose block the other three siblings in this family
  use, for consistency, or whether the terser form is fine as its own
  documented exception. Either way, state the decision in this item's
  spec explicitly rather than leaving it implicit.

Either way, re-run the probe above and paste its output. If the
contract changes shape (arity-separation branch), also leave a note on
this item naming `cosmic/re.tl:280` and `:326` as the cosmic-side sites
a follow-up item (filed separately, in the `cosmic-lua/cosmic` repo)
will need to simplify — do not make that edit here, since it is a
different repo.
