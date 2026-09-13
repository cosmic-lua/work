Blocked on the wave-2 pin (the constants this writes against) and the
R1 report shapes; the vocabulary is settled now:

1. **`cosmic/sandbox/init.tl`**: `record Scope` —
   `signal: boolean`, `abstract_unix: boolean` — and
   `Options.scope: Scope`. `true` confines that category to the sandbox
   domain (Landlock scoping is deny-outside, not per-target grants, so
   booleans are the honest shape — there is nothing path-like to list).
   Absent section: no scoping. `validate` accepts only the two keys.
2. **`cosmic/sandbox/landlock.tl`**: the `scoped` mask reaches
   `unix.landlock_create_ruleset`; `abi_mask` learns the ≥5 rung
   (IOCTL_DEV joins the `WRITE` composite beside TRUNCATE, stripped
   below ABI 5 — its doc comment carries the R2 rationale) and the ≥6
   rung for scopes. Below the needed ABI: `strict` refuses; otherwise
   the section reports `"degraded"`/`"skipped"` through the R1 grammar,
   never silently.
3. **TSYNC**: `restrict` passes the all-threads flag whenever ABI ≥ 8 —
   unconditional, no vocabulary (single-threaded today, correct the day
   the runtime is not; the epic's thread-scope friction closes).
4. **ABI 9**: adopt its additions uapi-verbatim under the same
   pattern — handled when expressible, reported when not.
5. **Report**: `Report.scope: Section`, same grammar as fs/sys/net.
6. **Tests**: the ABI-gated style the net slice establishes — skip on
   probed ABI below the feature, live on CI kernels at or above it; a
   scoped policy on an ABI ≥ 6 kernel refuses a signal to an
   outside-domain process (fork a peer pre-restrict, signal
   post-restrict, assert EPERM); ioctl-dev: an `rw` grant on a tty/dev
   fixture keeps isatty(3) working inside the tree on ABI ≥ 5.
