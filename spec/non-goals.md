- No change to sigaction's raise-on-invalid-signal-number path
  (`lunix.c:2648-2651` already raises via `luaL_argerror`) — this
  capture is only about the failure TUPLE, not `sig` validation.
- Does not re-litigate whether EINVAL-for-SIGKILL/SIGSTOP should
  itself become a raise instead of a returned failure — a program
  generically iterating all signal numbers can legitimately hit this,
  so it stays in the environmental/data-dependent bucket.
