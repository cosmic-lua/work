Find why `_work.repository_map`'s lookup returns the running tool's
checkout for an item whose repo is mapped elsewhere, and fix it at the
lookup so every caller gets the same corrected answer. Confirm both
symptoms above go away, and say in the PR body which call sites were
affected — a fix that only repairs `show` leaves the brief defect live.

Resolve the spec bar's path check against the item's repository at a
known commit — its recorded `claim base` when it has one, else the
repo's default-branch tip — rather than against a working tree, so the
answer stops depending on which branch a checkout is parked on.

Add cases: an item whose repo maps to a checkout other than the running
one resolves to the mapped checkout; a path present at the resolved
commit but absent from a checkout's working tree is NOT reported absent;
a path genuinely absent at that commit still is; and a review brief for
an item in a non-running repository names that repository's checkout in
both its prose and its `--repo-dir` lines.
