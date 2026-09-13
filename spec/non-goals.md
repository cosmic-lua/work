- `abi_mask` and every enforcement path stay untouched: `KNOWN_ABI` is
  knowledge, not policy, and this slice changes no runtime behavior.
- no modeling of ABI 4–9 access rights — that is the parent's phase 2/3
  (R6/R7), gated on whilp/cosmopolitan binding work.
- no change to the C bindings or `definitions.lua`.
- no touching `unveil.tl` / `quicksand` probes (R5 landed; PR #1278).
