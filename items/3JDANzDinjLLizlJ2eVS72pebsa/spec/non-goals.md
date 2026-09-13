Not re-investigating whether this file is currently exposed to the race
(PR #123 already established it is not, via plumbing-only commits) —
this is purely closing the one inconsistent copy of an already-decided
defensive pattern, at the same "zero measurable cost" PR #123 itself
used to justify applying it to files not currently exposed either.
