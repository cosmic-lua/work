# Decide: symmetric encryption API shape for cosmic.crypto (research item)

## Goal

Settle, as a `docs/decisions/` record, the design questions #193 leaves
open before any code lands for `cosmic.crypto.encrypt`/`decrypt` — then
file the resulting build items. This is proposed as a **research item**
(per `bin/gitboard help bar`'s allowance: "research is an item whose
deliverable is recorded findings and follow-up items, not code"), not a
build item, because the work genuinely spans two repos and turns on
product/contract decisions nobody has made yet, not on scoping alone.

## Evidence

The tree has no symmetric-encryption surface today:

```
$ ls cosmic/ | grep -i crypto
(no output)
$ find . -maxdepth 2 -iname "*crypto*"
(no output — no cosmic/crypto.tl, no cosmic/aes*.tl)
```

`cosmic/hash.tl:1-2` — the module's own doc header — states its scope
precisely: "Cryptographic digests, HMAC, and Argon2 password hashing.
Wraps cosmo.GetCryptoHash and cosmo.argon2." Digests and password
hashing (one-way) are a different primitive from symmetric encryption
(reversible, needs a cipher + a nonce/IV story), and `hash.tl` does not
touch it.

On the cosmopolitan side (`/home/user/cosmopolitan`, `git fetch origin`
run, tree unchanged), mbedTLS is vendored and already linked for
outbound HTTPS, but no generic cipher primitive is exposed to Lua:

```
$ ls tool/net/*.c | xargs -I{} basename {}
dig.c drift.c echo.c getadaptersaddresses.c largon2.c launch.c lcov.c
lfetch.c lfuncs.c lgetopt.c ljson.c llua.c lpath.c lre.c lsqlite3.c
lzip.c redbean-original.c redbean-static.c redbean-unsecure.c
redbean.c stampd.c winbench.c
```

`largon2.c` is Argon2 (password hashing) only — there is no `lcrypto.c`
or equivalent. `grep -rn "mbedtls_gcm\|mbedtls_cipher\|mbedtls_aes"
tool/net/*.c` finds mbedTLS's AES only inside `redbean.c`'s own TLS
server setup (`mbedtls_aes_uses_hardware()`, line 7009) — internal to
the HTTPS handshake, not exposed as a callable Lua primitive. So a
`cosmic.crypto.encrypt`/`decrypt` binding has no existing C entry point
to wrap; one must be added in cosmic-lua/cosmopolitan first, per that
repo's own `AGENTS.md`: "binding contracts... are frozen at the C
boundary — cosmic's generated types and wrappers depend on them,"
landed "as its own change, never inside an optimization" (or, by the
same logic, never bundled silently inside the cosmic-side wrapper PR).

This is the same shape of blocker cosmic's own issue #500 already
named for a sibling module: "`cosmic.tls` (P2) — needs the mbedTLS
wrap, U4 (cosmopolitan#143)." Fetched cosmopolitan#143 ("U4: expose
mbedTLS socket wrap (`wrap_client`/`wrap_server`) for cosmic.tls",
open) confirms the pattern — that issue is about wrapping an arbitrary
socket in the TLS *transport* handshake, a different binding shape from
a one-shot data-at-rest cipher call, but the same underlying vendored
library and the same "add the binding upstream first" sequencing.
#193's encryption ask is not a duplicate of #143/U4, but it is a
sibling blocked the same way, and should be sequenced the same way
(cosmopolitan lands the primitive; cosmic lands the wrapper as a
separate, later change).

No design decision or board item currently covers this:

```
$ bin/gitboard find "crypto"     # 4 hits, none an encryption-API decision
$ bin/gitboard find "encrypt"    # 0 hits
$ bin/gitboard find "aes"        # 1 hit, unrelated (JSON perf item)
$ ls docs/decisions/ | grep -i "crypto\|security"
(no output)
```

The open questions are genuine tradeoffs, not scoping details — they
meet the `decide` skill's bar ("constrains future work," "something
real was given up," "the reason is not visible from the code"):

1. **Algorithm.** mbedTLS (already vendored) supports both AES-256-GCM
   and ChaCha20-Poly1305. The issue's own sketch names "AES-256-GCM or
   similar" without picking. Whichever is chosen becomes the on-disk
   wire format every future caller depends on.
2. **API surface.** The issue proposes two independent APIs in one
   sketch — raw-key `encrypt`/`decrypt` AND password-based
   `encrypt_with_password`/`decrypt_with_password` (the latter implying
   an Argon2-derived key, tying it to `cosmic.hash`). That is exactly
   the "and" the spec bar says to cut into two changes, but which one
   ships first — or whether both are one slice because the password
   variant is a thin wrapper over the raw-key one — is itself the
   decision.
3. **Nonce/IV handling.** Generated internally and prepended to the
   ciphertext (self-describing output, the common modern default) vs.
   caller-supplied (more flexible, more footguns) is a contract choice
   that fixes the return shape.
4. **Error contract at the C boundary.** cosmopolitan's own `AGENTS.md`
   states the binding-contract rule precisely: an argument-shape error
   raises via `luaL_argerror`; a runtime failure (bad ciphertext, a
   failed GCM tag check — i.e. tampered/wrong-key input) returns the
   fallible tuple. Deciding which failures are which for a cipher
   binding (a failed auth-tag check is not a syscall failing, so is
   slot 3 `errno`, or a different documented value per the AEAD-failure
   case?) is exactly the kind of per-binding deviation that repo's
   `AGENTS.md` says must be "recorded in its `definitions.lua` `@return`
   doc" — a decision, not an implementation detail.
5. **Sequencing and repo split.** Given point 1, the cosmopolitan-side
   binding is a prerequisite, landed and released (bumping
   `3p/cosmos/cosmos_pin.tl`) before the cosmic-side wrapper can be
   built at all — mirroring the Wave-1-gated-on-U4 pattern #500 already
   states for `cosmic.tls`.

## Change

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

## Non-goals

- Does not implement any binding or wrapper — that is explicitly
  deferred to the two follow-up items the record produces.
- Does not re-litigate `cosmic.hash`'s existing scope (digests, HMAC,
  Argon2 password hashing) — those stay as they are regardless of what
  this decides.
- Does not decide anything about `cosmic.tls`/cosmopolitan#143 (the
  transport-level TLS wrap) beyond noting the sequencing parallel; that
  stays its own tracked item under #500.

## Access

- `cosmic-lua/cosmic` (read+write): the decision record lands here.
- `cosmic-lua/cosmopolitan` (read-only): consulted for `tool/net/*.c`,
  `tool/net/definitions.lua`, and the vendored `third_party/mbedtls3/`
  surface to ground the record's algorithm/contract choices in what is
  actually vendored; no change lands there from this item.
