Produce `docs/decisions/dNN-symmetric-encryption-api.md` (next free
decision number; `ls docs/decisions/` currently ends at `d45`) settling,
as one record: the algorithm (AES-256-GCM vs ChaCha20-Poly1305, or
both), the API surface (raw-key only for the first slice, per-password
convenience layered later or not at all), the nonce-handling contract,
and the error-classification contract for the new C binding, following
the `decide` skill's four-section form (`skills/decide/SKILL.md`).

Then file two follow-up build items reflecting the sequencing the
record settles:

1. **cosmic-lua/cosmopolitan**: add the mbedTLS cipher binding (a new
   `tool/net/l<name>.c` or an addition to an existing binding file) plus
   its `tool/net/definitions.lua` entry, following that repo's frozen
   contract rules — its own item, its own PR, gated on
   `make -j$(nproc) o//tool/lua/test`.
2. **cosmic-lua/cosmic**: `cosmic/crypto.tl` (or fold into `cosmic/hash.tl`
   if the record decides that), wrapping the new `cosmo.*` binding,
   blocked on (1) shipping in a tagged cosmopolitan release and
   `3p/cosmos/cosmos_pin.tl` bumped to it — the same gate `cosmic.tls`
   already waits behind for U4.

This item's own deliverable is the decision record plus these two filed
items — no `cosmic/crypto.tl` code, and no cosmopolitan C code.
