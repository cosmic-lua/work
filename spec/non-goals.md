No path resolution or guessing ("did you mean"). No change to the bar's
refusal set.

Also, from PR #45's review: `_work/overlap.tl:113` `local text = fs.read(path)` discards the error slot; capture it and render the failure as `unreadable: <path>: <err>` in the same list — the module's other `fs.read` sites all keep `rerr`.
