Not re-auditing the whole tree for every other reference to
`_build/casts_test.tl`/`cast_lines` beyond the four sites named above
— those were the ones the sibling item's own out-of-scope report
surfaced; if this item's own `grep` turns up more while fixing these,
fix them too (it's the same class of edit), but don't go looking
beyond what a full-tree `grep -rn "cast_lines\|casts_test\.tl"` finds
today.
