All names, values, and struct offsets are taken VERBATIM from the
current kernel uapi `linux/landlock.h` at implementation time — the
authoritative source this spec deliberately does not transcribe. What it
does fix:

1. **`libc/calls/landlock.h`**: ABI 5's device-ioctl fs bit; ABI 6's
   `scoped` ruleset field and its `LANDLOCK_SCOPE_*` bits
   (abstract-unix-socket, signal); ABI 7's audit/logging restrict_self
   flags; ABI 8's all-threads (TSYNC-style) restrict flag; ABI 9's
   additions. Each with the header's `@note ABI N+` doc style.
2. **`third_party/lua/lunix.c`**: `landlock_create_ruleset` gains the
   `scoped` mask as its next optional argument, size-gated by argument
   presence exactly per wave 1's rule (fs-only calls keep sending
   fs-only bytes); `landlock_restrict_self`'s flags argument passes the
   new flags through (measured: the wrapper already takes flags —
   only constants are needed). Register every new constant; no existing
   signature moves.
3. **`tool/net/definitions.lua`** in the same commit, per the ratchet.
