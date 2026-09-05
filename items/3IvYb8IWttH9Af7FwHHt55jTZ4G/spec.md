## Goal

`gitboard show ID` prints only the immediate `parent:` — one hop, and
even that is a bare id with no title (`parent: 3It7vrCkv6jhCTRa2ieBb5nSBqt`).
Seeing where an item actually sits in the tree — its outcome, and every
container in between — means calling `show` again on the parent, then
again on the grandparent, by hand, as many times as the tree is deep.
Print the whole ancestor chain in one `show ID` call instead.

## Evidence

`_work/gitshow.tl:128`, the entire ancestor rendering today:

```lua
if it.parent ~= "" then out[#out + 1] = ("parent: %s"):format(it.parent) end
```

One line, raw id, no title, no further ancestors. Reproduced live
today auditing the board's own placement: `3I1j7yQAawHLQwtQA1bp1i3tUj4`
(the `cosmic.fuzz` epic, whose own spec states `## Goal — G5 —
adversarial verification`) showed:

```
$ bin/gitboard show 3I1j7yQA
parent: 3It7vrCkv6jhCTRa2ieBb5nSBqt
```

Nothing there says what `3It7vrCkv6jhCTRa2ieBb5nSBqt` is, let alone
that its own parent is `3IvL3eLKmAvbo7wy5j787Ez91h9`, whose parent is
`3HyRcrR35sYRwZl3guddvOBhFoK` (G9) — three more `show` calls, one per
level, to learn the epic actually resolves under G9 despite stating
G5 as its own goal. `_work/flow.tl` already has the walk this needs,
proven safe against cycles: `reaches_board` (line 283-295) and
`outcome_of` (line 303-315) both walk `index[cur.parent]` bounded by
`it.MAX_DEPTH`, stopping at `is_board`. Neither prints the path it
walks; both just answer a yes/no or "which outcome" question.

## Change

In `_work/gitshow.tl`'s `show_report`, replace the single `parent:`
line with an ancestor chain: walk `it.parent` up via `index[cur.parent]`
(the same bounded loop `reaches_board`/`outcome_of` already use, so
depth-limit and cycle behavior match) and print one line per level,
nearest first, each carrying the ancestor's handle and title — stopping
at (and including) the board. A leaf directly under an outcome prints
one line; the epic above prints three, ending at G9, so the resolved
outcome is the last line rather than a separate lookup. No new field:
this is what `parent:` already meant, just fully walked instead of
truncated at one hop. Add a case to `_work/gitshow_test.tl`: an item
three levels deep prints all three ancestors in order, nearest first.

## Non-goals

Not adding a way to mark WHY a given edge exists (decomposition vs. a
dependency expressed as a child per `help bar`) — decomposition is a
special case of dependency, not a distinct relation the tree needs to
tag, and the ancestor chain above already lets a reader see a stated
`## Goal` diverge from the outcome the chain resolves to without one.
