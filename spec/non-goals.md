Not a validation/refusal for a base that doesn't contain the spec's
named paths (a "does this branch actually have `_work/foo.tl`" check) —
that is a heavier, separate mechanism (parsing spec prose for paths,
resolving them against a branch listing) worth its own item if this
narrower fix does not fully close the gap. This item only removes the
two-step, easy-to-forget pattern by letting `--base` be set at `new`
time, same as `--repo` already can be.
