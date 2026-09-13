In `needs_space` (`cosmic/format/rules.tl:223-231`), add a check: when
`cur.tk == "-"` as well as `prev.tk == "-"`, always return `true`
(keep the space) regardless of what `prev_prev` is — two adjacent `-`
tokens must never touch, independent of whether the first is unary or
binary, because concatenating them always re-lexes as a comment.
