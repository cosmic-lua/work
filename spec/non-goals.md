- **Not a change to any number in `LIMITS`.** The hard rules forbid
  widening a limit to make a move succeed, and this item is not a
  request to do so; it is about what the existing number COUNTS.
  Retuning the numbers is the flow review's job (`review.md`), and a
  fix here must be neutral to them.
- No change to what `blocked` means, to `block`/`unblock`, or to the
  blocker-edge predicate the fix reuses.
- No change to `next`'s ordering, beyond whatever falls out of a phase
  no longer being at its limit.
- Not a re-ranking or re-parenting of the four items in the evidence.
