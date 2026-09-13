The decision that bullet leaves open, settled here: the alarm's threshold
is the highest ABI cosmic KNOWS EXISTS — not the highest it ENFORCES.
`abi_mask` (cosmic/sandbox/landlock.tl:137) enforces through ABI 3, and
GitHub's ubuntu-24.04 runners ship kernel 6.8, which reports ABI 4 — an
alarm on the enforced ceiling would be born red, and a permanently red
test is noise, not an alarm. The unenforced ABI 4–9 surface is already
this item's parent's tracked work (R6/R7); what nothing tracks is an ABI
the parent's evidence has never heard of shipping. The parent's 2026-08
review against go-landlock and rust-landlock is current to ABI 9, so:

1. **`cosmic/sandbox/landlock.tl`** (295 lines, 205 of headroom): add a
   module constant

   ```teal
   local KNOWN_ABI < const > = 9
   ```

   with a doc comment naming what each ABI past the enforced ceiling
   adds (4 TCP bind/connect, 5 ioctl, 6 signal + abstract-unix scoping,
   7 audit, 8 TSYNC, 9 pathname unix sockets) and the rule: raising it
   is only done by the change that records the new ABI's access bits in
   the parent epic's evidence. Export it: field
   `known_abi: integer` in the record (beside `abi` at line 130) and
   `known_abi = KNOWN_ABI` in the return table (beside `abi = abi` at
   line 290).

2. **`cosmic/sandbox/landlock_test.tl`** (353 lines, 147 of headroom):
   add `test_abi_drift_alarm`, called on the line after its `end` per
   house convention. Body: `local a = landlock.abi()`; when `a` is nil,
   return — non-Linux hosts and Landlock-less kernels skip (this repo's
   sandboxed CI kernel returns `ENOSYS`, measured 2026-08-19). Otherwise
   assert `a <= landlock.known_abi` with a message carrying both numbers
   and the instruction: "kernel reports Landlock ABI %d, above the
   highest cosmic knows (%d); review what the new ABI adds and record it
   in the G2 epic before raising known_abi".

No cast is needed anywhere in this diff; `abi()` already returns
`integer | nil, string` and truthiness narrows it.
