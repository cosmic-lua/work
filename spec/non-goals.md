Not touching `cosmic/sqlite/extras.tl:63,106` or `cosmic/_teal_engine.tl:256`
— both confirmed unrelated to the zero-return-arity defect this patch
targets (re-verified this session, not merely re-asserted) and filed as
their own items citing this item's evidence:
`3ItmrMCMu3qgT1dOglnXwrh16CG` («tl: sqlite/extras.tl's pcall-failure-arm
mistyping...») and `3Itms9dT2FcpDX5x8mqTjmjtQcb` («tl:
_teal_engine.tl:256's TlResult/tl.Result nominal duplication...»).

Not widening pcall's slot 2 for any callee with declared return arity
>= 1 — that case already gets the callee's own real return types from
today's checker with no defect for this item's target sites, and doing
so tree-wide is exactly what broke `--make ci` at 9+ files in the
original attempt.

Not removing the now-redundant `as (boolean, any)` casts at
`cosmic/shm.tl:146,171` — left as-is per the Change section above.
