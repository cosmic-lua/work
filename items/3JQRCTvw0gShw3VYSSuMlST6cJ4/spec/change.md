In cosmic's bin/cosmic cold-bootstrap path, reuse existing pristine runtime
bytes after checking a private snapshot against that launcher's committed
pin. The current path at c46ba274 requires both a stamp and an MZ executable,
so verified bytes supplied by worktree preparation without a stamp still
lead to a download. Consult work PR203's shared SHA256 cache contract when
refining the implementation, including its per-user path and no-overwrite
publication behavior.

Preserve cosmic's raw MZ bootstrap contract; do not import work's native-ELF
assimilation. Prove actual launcher reuse with downloads refused and no
built tree binary. Reject corrupt or transformed bytes even if a stamp or
filename appears to match. Refine the exact production/test scope against
the current launcher before claiming implementation.
