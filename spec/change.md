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
