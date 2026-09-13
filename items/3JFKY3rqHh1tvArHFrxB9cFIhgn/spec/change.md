Compute a review's range as the merge-base diff between the handover
commit and the item's base branch — `git diff <base>...<head>`, three
dots — so a branch that merged its base forward is still reviewed on its
own change. Resolve `<base>` from the item's own `base` field when it has
one, falling back the way the briefs already resolve a default branch.

Refuse rather than render when the computed base is not an ancestor of
the handover: a range that cannot describe the change is worse than no
range, because it looks authoritative. Say what was expected and what was
found.

Add cases: a branch that merged its base forward reviews only its own
diff; a base that is not an ancestor of the head is refused, naming both;
and a simple branch with no forward merge is unchanged.
