Measured 2026-08-19 at whilp/cosmopolitan `0980e033`:

1. **`libc/calls/landlock.h`**: `struct landlock_ruleset_attr` (today
   only `handled_access_fs`) gains `uint64_t handled_access_net`;
   `enum landlock_rule_type` gains `LANDLOCK_RULE_NET_PORT = 2`; add
   `struct landlock_net_port_attr { uint64_t allowed_access; uint64_t
   port; }` and bits `LANDLOCK_ACCESS_NET_BIND_TCP` /
   `LANDLOCK_ACCESS_NET_CONNECT_TCP` — values verbatim from the kernel
   uapi `linux/landlock.h`, with doc comments in the header's existing
   style (`@note ABI 4+`).
2. **The size trap, settled — this is the wrong turn to not take.**
   `LuaUnixLandlockCreateRuleset` (`third_party/lua/lunix.c` ~1091)
   passes `sizeof(attr)` today; once the struct widens, that would send
   pre-6.7 kernels a size they do not know, and Landlock's contract
   answers E2BIG. The wrapper must choose the size by what the caller
   asked for: fs-only call → size through `handled_access_fs`
   (`offsetofend`-style, the exact bytes today's binary sends, so every
   existing caller is bit-identical); a call with a net mask → size
   through `handled_access_net`.
3. **Additive Lua surface**, existing signatures frozen:
   `unix.landlock_create_ruleset(handled_fs[, flags[, handled_net]])` —
   the argless ABI-probe form and the 1–2 arg forms unchanged; new
   `unix.landlock_add_net_rule(ruleset_fd:int, port:int, allowed:int)`
   for `LANDLOCK_RULE_NET_PORT` (a new function, so the 4-arg
   path-beneath `landlock_add_rule` contract does not move). Register
   the two NET constants beside the FS block (~4906–4930).
4. **`tool/net/definitions.lua` in the same commit** (constants block
   ~3971, function annotations ~7405) — the annotation-coverage ratchet
   in the test target enforces it.
