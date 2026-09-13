Update `tool/net/definitions.lua`'s `unix.Dir:fd()` doc comment to
drop the stale EOPNOTSUPP claim and describe the current, unconditional
behavior (always returns the directory stream's underlying file
descriptor as a plain integer). Separately, once this lands, consider
(implementer's judgment, not required by this capture) whether
`cosmic/fs/dir.tl`'s `raw:fd() or -1` defensive fallback can simplify
now that the underlying claim it defends against is confirmed false —
not required here.
