Bump `3p/cosmos/cosmos_pin.tl` to a cosmos release descending from
cosmopolitan #385/#386 (verify the exact release tag and sha256 against
the cosmos release list; the evidence above names
`2026.09.06-bee599a73` as A release that carries it, from unrelated
work — confirm it's still current or find the latest one that is),
then `bin/cosmic --make fetch && bin/cosmic --make ci` to confirm the
bump alone doesn't regress anything else the newer pin's generated
types touch.

Once landed, `gVi7_9Ne8` unblocks: resume it (it already has a
correctly-scoped `## Change`) rather than respeccing its narrowing
logic — only the missing pin was in its way.
