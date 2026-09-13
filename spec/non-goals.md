Reads stay untouched (they already work on a dirty tree). No
change to the CAS contract: a lost race still drops the mutation
whole and refuses with recovery named. No stash use anywhere. The
handover-model sibling (3IZZ1icV) stays separate.

---

(Original evidence, 2026-08-29, pre-split file layout:)
- **Do not weaken the compare-and-swap publish.** The push-as-CAS in
  `_work/store.tl` `publish` — reject, diagnose, drop the whole
  mutation, re-sync, refuse with `LOST_RACE` — is the existing and
  correct mechanism for two sessions writing `items/**` concurrently.
  It stays. Narrowing HOW the drop is performed is in scope; changing
  WHETHER a lost race drops the mutation is not.
- **Do not let a mutation skip validation.** Every gate — WIP, ready
  bar, priority placement, claim, `item.problems` — still runs against
  the merged board before the commit is made. A mutation that cannot
  sync must refuse, not proceed on stale state.
- **Do not make `--force` the answer.** `--force` is for a judged
  exception to a board rule, not for a dirty checkout.
- **Do not introduce `git stash` anywhere in the machinery.** The stack
  is shared across every worktree of this repo; the machinery must never
  push to it, and the docs must never recommend it.
- **No change to the one-mutation-one-commit rule.** `save` writing
  exactly one commit is what makes the race recovery exact.
- Not a change to reads. They already work on a dirty tree.
