## Goal

Produce a concrete decomposition plan (and, if the inventory below turns
out smaller than feared, a first buildable slice) for migrating
redbean's TLS server surface off the hand-forked Mbed TLS 2.26
(`third_party/mbedtls`) onto the already-vendored 3.6 LTS package
(`third_party/mbedtls3`), so `third_party/mbedtls`, `net/https`, and
`test/net/https` can eventually be deleted. This is upstream issue
https://github.com/cosmic-lua/cosmopolitan/issues/187, verified still
open against `origin/master` (`780f45055acd52401de6c95c16365338690e19e7`,
fetched 2026-09-12) with none of its four stated sub-tasks done.

This item is a **research item**, not a code change: per this board's
`bar` doctrine ("research is an item whose deliverable is recorded
findings and follow-up items, not code"), the port itself is far past
the ~400-line sizing threshold and must not be pulled as a single
change. Its deliverable is: (a) a confirmed, current-tree inventory of
exactly what `net/https` does that `net/https3` doesn't yet, (b) a
mapping from each fork-only mechanism to its Mbed TLS 3.6 native
replacement (issue #187 itself already names two: native
`mbedtls_x509write_crt_set_subject_alternative_name` /
`set_ext_key_usage` replacing the fork's hand-added `san.c`), and (c) a
set of filed, file-disjoint-where-possible follow-up board items sized
under the smell threshold, ordered as a dependency chain.

## Evidence

The migration has **not** happened for the server side. The client side
has: `git log --oneline -- third_party/mbedtls third_party/mbedtls3
net/https net/https3 tool/net/lfetch.c` shows

```
e21155f8 mbedtls3: slim the config to the lua client's needs (#186) (#258)
1c5cfce4 lua: restore the GetCryptoHash contract and SHA-256 speed on Mbed TLS 3.6 (#190)
34ab4369 lua: cut the lua binary over to Mbed TLS 3.6 LTS (#183)
81ce7622 mbedtls3: vendor Mbed TLS 3.6.6 LTS as a parallel package (#182)
```

— all client-facing (`lfetch.c`, the lua binary's `Fetch`). `net/https`
(server-side: cert generation, `x509write` SAN/EKU, `ChainCertificate`,
`TlsRoute`, etc.) is untouched and still depends on the 2.26 fork:

```
$ grep -n "THIRD_PARTY_MBEDTLS" net/https/BUILD.mk
39:	THIRD_PARTY_MBEDTLS			\
$ grep -n "NET_HTTPS\b\|THIRD_PARTY_MBEDTLS" tool/net/BUILD.mk
58:	NET_HTTPS							\
69:	THIRD_PARTY_MBEDTLS						\
```

and redbean's own link line (from a real `make -j$(nproc)
o//tool/net/redbean` run today) still pulls in both:

```
...o//net/https/https.a o//third_party/mbedtls/mbedtls.a...-o o//tool/net/redbean.dbg
```

`third_party/mbedtls` (the 2.26 fork) is still present and versioned
2.26.0 (`third_party/mbedtls/version.h:19`:
`#define MBEDTLS_VERSION_STRING "2.26.0"`), next to
`third_party/mbedtls3` at 3.6.6
(`third_party/mbedtls3/include/mbedtls/build_info.h:37`:
`#define MBEDTLS_VERSION_STRING "3.6.6"`).

Sizing check — why this cannot be one item:

```
$ wc -l net/https/*.c net/https/*.h | tail -1
1572 total
$ find third_party/mbedtls -name "*.c" -o -name "*.h" | xargs wc -l | tail -1
173951 total
$ ls net/https3/
BUILD.mk describesslverifyfailure.c getentropy.c getsslroots.c https3.h
initializerng.c sslroots.c tlserror.c
```

`net/https3` today is client-only (entropy/RNG init, embedded root
store, TLS error formatting) — none of `net/https`'s server-side cert
authoring (`certs.c`, `chaincertificate.c`,
`generatecertificateserial.c`, `choosecertificatelifetime.c`,
`isselfsigned.c`, `finishcertificate.c`, `formatx509name.c`, ...) has a
3.6 counterpart yet. Porting ~1572 lines of cert-authoring logic plus
retiring a 173,951-line vendored library plus the `redbean.c`/
`tool/net`/`test/net/https` wiring changes the issue's task list
describes is a multi-file, multi-week effort by the issue's own
admission ("This is a multi-week project, not a quick swap").

## Change

Not applicable in the imperative-code sense — see Goal. The concrete
research deliverable:

1. Enumerate every `net/https/*.c` file's public surface (`grep -n
   "^[A-Za-z].*(" net/https/*.h`) and classify each function as: (a)
   has a native Mbed TLS 3.6 replacement (name it, e.g. `san.c`'s SAN/EKU
   writers → `mbedtls_x509write_crt_set_subject_alternative_name` /
   `set_ext_key_usage`), (b) needs a thin adapter over an existing 3.6
   API, or (c) needs new code with no 3.6 analog. Record the counts and
   per-file line estimates.
2. Confirm gh#184's crash does or doesn't reproduce on a 3.6-linked
   server once the sibling fix for gh#184 (see dependency below) lands
   — the issue's own task 2 ("Fix #184 in the process, or confirm 3.6's
   server-side parser doesn't have the crash") is answered either way by
   that item, not by new work here.
3. From the classification, file follow-up board items — expected
   shape based on the inventory above: one item per `net/https` file or
   small file group, one item for the `redbean.c`/`tool/net`
   `THIRD_PARTY_MBEDTLS`→3.6 BUILD.mk swap and `USE_MBEDTLS3` unification
   in `lfuncs.c` (`grep -n "USE_MBEDTLS3" tool/net/lfuncs.c` currently
   shows 4 guarded blocks at lines 72, 789, 845, 1136, 1143 to fold back
   to unconditional), and a final item for deleting
   `third_party/mbedtls`, `net/https`, `test/net/https`, and the
   `lfuncs3.c` shim. Rank them as a dependency chain (cert-authoring
   pieces before the BUILD.mk swap before the deletion), matching this
   board's container/child pattern used elsewhere for staged work.

## Non-goals

- Do not attempt the actual C port in this item.
- Do not touch `third_party/mbedtls` or delete anything yet — deletion
  is the last item in the chain this research produces, gated on every
  earlier piece having landed and `make -j$(nproc) o//tool/net/redbean
  o//tool/lua/test` passing with the 3.6-only link.
- Do not re-decide gh#184's fix here — it is its own item and this
  item's task 2 is satisfied by that item's outcome, not duplicated.

## Access

- cosmic-lua/cosmopolitan: read-only for this item (inventory and
  planning only).
- cosmic-lua/cosmic: none needed for the research pass itself; note for
  whoever picks up the follow-up items that this repo's own AGENTS.md
  rule applies once real binding/contract changes land here — "a
  deliberate contract change needs a matching `definitions.lua` update
  here and a type regen + wrapper fix on the cosmic side, landed as its
  own change, never inside an optimization" — so each follow-up item
  that changes a `cosmo.*`-visible contract will need read+write access
  to cosmic-lua/cosmic in its own spec.

## Dependency ordering (this batch)

Blocked by: the gh#184 fix (`issue_184.md` in this same batch) — #187's
own task list makes this explicit ("Do it after #184 is root-caused").
That item is small and already specced; pull it first. Nothing else in
this batch blocks or is blocked by #187: gh#185 (client TLS 1.3) is
independent per its own issue text; gh#148 (CA bundle), gh#144 (IPv6),
and gh#143 (wrap_client/wrap_server) touch unrelated surfaces
(`tool/net/lfetch.c`/`fetch.inc` opts, `third_party/lua/cosmo/lunix.c`
sockets, and a new TLS-wrap binding respectively) and do not need this
migration to land first.
