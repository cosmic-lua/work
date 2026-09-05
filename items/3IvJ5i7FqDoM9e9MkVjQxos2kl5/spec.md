## Change

Open specs on this board still name verbs the tool no longer has —
`compare`, `block`, `unblock`, `hold`, `unhold` — and the `blocked_by`
edge. Sweep them: `gitboard find "gitboard compare"`, `find "gitboard
block"`, `find "gitboard hold"`, `find blocked_by` (each list is capped
at 20, so repeat until a search returns nothing new), open each hit
with `show ID`, and replace the sentence with what the tool does now:
ranking is `rank ID --before|--after|--last` (`help order`), a
prerequisite is a child of the item that waits on it (`new --parent
ID`), a verified outcome is `done --reason completed --by CHILD`.
Replace the spec with `spec ID FILE`, one item per commit. A spec
whose only content was a blocker procedure needs no other change.
Measure first: the count of items touched goes in this item's PR
description, with the `find` commands that produced it.
