Answer three questions and record each with the command or `file:line`
that produced it, in a `## Findings` section appended to THIS item's
spec (`o/bin/gitboard spec 3IKuRFN5 FILE`, from the board worktree).

**1. Why the `next` member is vestigial**, from upstream history,
which this fork's log cannot reach:

```
git clone --filter=blob:none --no-checkout \
  https://github.com/jart/cosmopolitan /tmp/upstream-cosmo
git -C /tmp/upstream-cosmo log --oneline -- \
  libc/zipos/ libc/runtime/zipos-open.c libc/runtime/zipos-close.c
git -C /tmp/upstream-cosmo show <candidate sha> -- \
  libc/zipos/zipos-open.c libc/runtime/zipos-open.c
```

The listing is metadata only, so the blobless clone stays cheap;
`show` then fetches just the revisions you name. Do NOT reach for
`git log -S` here — a pickaxe over a blobless clone refetches every
revision of those paths one at a time, and this file's history is
short enough to read by eye. Upstream carried these sources under
`libc/zipos/` before the path moved, which is why both prefixes are
listed. Record the commit that removed the freelist, its message, and
the
removal diff. Then state in ONE sentence whether it came out for a
CORRECTNESS reason — name it — or for another reason (a simplification,
a rewrite that dropped it incidentally, a measurement that found it
worthless). If no such commit exists, record that with the same
commands and their empty output: "the member was speculative and the
freelist never shipped" is a complete answer to this question, and it
is the answer that makes the parent cheap.

**2. Whether that reason still binds here.** For whatever question 1
returns, say against THIS tree whether it applies, walking the four
constraints quoted by `file:line` in Evidence: the async-signal-safe
push out of `__zipos_close`, `__vforked`, no `__fds_lock` held at
alloc time, and the fixed stored-member size.

**3. The design, decided.** Write the decision — not the options —
covering exactly these five points, each carrying its reason from 1
and 2:

- which allocations are recycled: the single fixed
  `sizeof(struct ZiposHandle)` bucket that `zipos-open.c:127` produces,
  or a size-bucketed list that also catches `:116` and `:132`;
- the PUSH side's synchronization, given `__zipos_drop` is reached
  from an `@asyncsignalsafe` `__zipos_close`;
- the POP side's, given `__zipos_load` already runs under
  `BLOCK_SIGNALS` on its own thread but holds no lock at `:127`, and
  given a signal handler on ANOTHER thread may be popping at the same
  moment;
- what BOUNDS the list, so a program that opens and closes many zipos
  members does not retain every handle for the life of the process:
  state the cap and what happens past it;
- what happens across `fork` (a child inheriting the list, and a child
  inheriting it mid-mutation) and across `vfork` (where
  `zipos-close.c:40` already skips the drop).

Then write the sibling implementation slice:
`o/bin/gitboard new "<title>" --parent 3IK8GFHj --repo
whilp/cosmopolitan --spec-file F`, with point 3's design as its
`## Change`, the parent's measured numbers as its `## Evidence`, and an
`## Acceptance` carrying `make -j$(nproc) o//tool/lua/test` plus the
`_perf` compare gate from `skills/optimize` — including that skill's
cross-session rule, because `startup_run_lua` is a fixed-overhead
scenario.
