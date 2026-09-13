Builds on the R1 report shapes and the wave-1 pin (both in
`blocked_by`). The vocabulary, settled to mirror `fs` exactly:

1. **`cosmic/sandbox/init.tl`**: `record Net` — `connect_tcp:
   {integer}`, `bind_tcp: {integer}` — and `Options.net: Net`. Same
   semantics as fs groups: a present-but-empty list denies that
   category entirely; an absent key leaves that category unrestricted;
   an absent `net` section means no network policy. `validate` refuses
   a non-integer or out-of-range (0–65535) port, naming index and
   value, before anything is applied.
2. **`cosmic/sandbox/landlock.tl`**: `RestrictOptions` gains the net
   masks; `restrict` passes `handled_access_net` to
   `unix.landlock_create_ruleset` and adds one
   `unix.landlock_add_net_rule` per allowed port. `abi_mask` (line 137)
   learns the ABI-4 gate: below ABI 4 the net request is not
   expressible — under `strict` that refuses; otherwise the section
   reports `"skipped"` with the ABI in `missing`, through the R1
   `Enforcement`/`Report` path, never silently.
3. **Report**: `Report.net: Section`, same grammar as fs/sys — which is
   why R1 lands first.
4. **Tests** (`landlock_test.tl` at 353/500 — split a
   `landlock_net_test.tl` beside it rather than crowding the cap):
   GitHub's ubuntu runners are kernel 6.8 = ABI 4, so this is live in
   CI: bind a loopback listener on an ephemeral port; apply
   `net = { connect_tcp = {<that port>} }`; connect succeeds; a second
   listener's port, not granted, refuses with EACCES. `bind_tcp = {}`
   then refuses a fresh bind. On ABI < 4 or non-Linux the tests skip on
   the probed ABI, the same convention the suite already uses (this
   repo's sandbox kernel: ENOSYS, measured).
