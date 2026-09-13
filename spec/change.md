**1. `skills/optimize/measurement.md`** — insert ONE bullet
immediately after the within-run-spread bullet that ends at `:20`
("…will flag these as \"regressions\" on pure noise."). The bullet
states, in the chapter's voice:

- the variance has a term no interleaving inside one session removes:
  host placement, invisible from inside a container because the
  microcode register is virtualized there;
- the rule that follows from it — **a release-gating regression on a
  single tight-loop or fixed-overhead scenario needs reproduction
  across SEPARATE SESSIONS, ideally days apart, before it blocks a pin
  or is written into a board item as a finding**;
- the #263 table above, in a fence tagged `text`, as the evidence,
  with the two facts a reader needs from it: one unchanged binary
  swung -38% between sessions, and the morning's regression had
  already reproduced across seven interleaved isolated pairs.

**2. `skills/optimize/SKILL.md`** — in step 6 ("decide"), extend the
surviving-regression bullet (`:183-191`) with a second defined
exception in the shape of the first: a surviving regression on a
single tight-loop or fixed-overhead scenario that is about to gate a
release or become a board item's finding is decided by the
cross-session rule in `measurement.md`, named by its heading words, not
by the one session's verdict. Keep the existing first exception
unchanged and keep the bullet's opening sentence ("a surviving
regression already reproduced against the binary itself, so it is
real") — the new clause narrows where that conclusion may be SPENT, it
does not weaken the gate.

Both edits are prose in two markdown files. No code moves.
