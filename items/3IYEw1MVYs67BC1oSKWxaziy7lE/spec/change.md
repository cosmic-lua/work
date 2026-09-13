Decide and implement which half of the contradiction is the intended
design, then make source, behaviour and prose agree.

The two candidate readings, both defensible:

1. **The comment is right and the walk is wrong.** A leaf's band should
   stay inherited unless a comparison reaches it from ABOVE its own
   level; comparisons among peers order them within the band via `own`,
   which is what `own` is already for. The fix is in the walk's
   stopping condition — an edge to a peer must not terminate it.
2. **The walk is right and the comment is wrong.** Carrying an edge
   really does mean "this item is placed on its own merits now", and
   the comment's promise must be deleted rather than implemented. If
   this is chosen, `compare` must SAY so — a verdict line that names
   the band each side moved from and to, so the demotion is visible at
   the moment it happens — and `SKILL.md`/`decompose.md` must stop
   describing `compare` as free of positional side effects.

Reading 1 is the one the rest of the system appears to assume; do not
treat that as settled without checking `_work/priority_test.tl`, whose
existing cases may already pin one reading.
