No filtering, no `--repo` selector, no machine-readable encoding. The parent
item holds the question of a general query surface and explicitly does not
choose a verb name or an encoding; this slice adds one rollup to the verb that
already exists and leaves that decision open.

`find` is untouched, and no existing `show` output changes when `--summary` is
absent.

The sibling item fixing `refresh --execute`'s bootstrap also edits
`_work/gitboard.tl`, which has 12 lines of headroom. Land whichever is ranked
first and rebase the other.
