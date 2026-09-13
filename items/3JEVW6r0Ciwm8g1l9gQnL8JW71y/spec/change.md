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
