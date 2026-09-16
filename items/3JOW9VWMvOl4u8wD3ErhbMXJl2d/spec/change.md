`gitboard take ID --repo-dir DIR` refuses with:

```
gitboard-take: REFUSED: not a commit id:
```

Nothing after the colon, because the refusal echoes the empty `--head` value
it was given rather than naming the option it wanted. The caller had assumed
`--repo-dir` was enough — the checkout's HEAD *is* the handover — and the
message neither confirms nor denies that reading. Recovery was reading
`help take` and re-running.

Two changes, either of which fixes it; the item is for deciding which and
doing that one:

- name the missing option, e.g. `--head is required: the product commit
  handed over`, instead of printing an empty value; or
- default `--head` to the product checkout's HEAD when `--repo-dir` is given,
  which is the common case and unambiguous, and keep the explicit form for
  everything else.

An error message whose entire payload is the empty string is strictly worse
than one with no payload, because it reads as a value that failed validation
rather than a value that was never supplied.
